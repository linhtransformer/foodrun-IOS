import SwiftUI

// Verlof (HQ decision 0082): ask an employer for days off, see what they decided (with
// their note), take back a request nobody decided on yet. Same rows as foodrun.nl/me/leave.

public struct LeaveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LeaveStore.self) private var leave
    @Environment(ScheduleStore.self) private var schedule
    @State private var asking = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let error = leave.lastError {
                    Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
                }
                Button { asking = true } label: {
                    Label("leave.ask", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.foodrun.backgroundInverseInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(Color.foodrun.foreground))
                        .frCTAShadow()
                }
                .buttonStyle(.plain)
                .disabled(schedule.employees.isEmpty)

                if leave.requests.isEmpty && !leave.isLoading {
                    Text("leave.empty").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                VStack(spacing: 8) {
                    ForEach(leave.requests) { row($0) }
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await leave.load(employeeIds: schedule.employees.map(\.id)) }
        .task { await leave.load(employeeIds: schedule.employees.map(\.id)) }
        .sheet(isPresented: $asking) {
            LeaveRequestSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            Text("leave.title").frText(FRType.screenTitle)
            Text("leave.subtitle").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private func row(_ r: DBLeaveRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: r.start_date == r.end_date ? PeopleFormat.day(r.start_date) : "\(PeopleFormat.day(r.start_date)) – \(PeopleFormat.day(r.end_date))")
                    .frText(FRType.rowTitle)
                Spacer()
                Text(LocalizedStringKey("leave.status.\(r.status)"))
                    .frText(FRType.fieldLabel)
                    .foregroundStyle(color(r.status))
            }
            if let reason = r.reason, !reason.isEmpty {
                Text(verbatim: reason).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            if let note = r.manager_note, !note.isEmpty {
                Text(verbatim: "“\(note)”").frText(FRType.rowSubtitle)
            }
            if r.status == "pending" {
                Button { Task { _ = await leave.withdraw(r) } } label: {
                    Text("leave.withdraw").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.foodrun.foreground)
                        .padding(.horizontal, 14).frame(minHeight: 34)
                        .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(leave.busy)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private func color(_ status: String) -> Color {
        switch status {
        case "approved": return Color.foodrun.subject.positive
        case "rejected": return Color.foodrun.subject.destructive
        case "pending": return Color.foodrun.subject.warning
        default: return Color.foodrun.mutedForegroundSoft
        }
    }
}

/// Days off from … to, a reason, at which employer (when there are several).
struct LeaveRequestSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LeaveStore.self) private var leave
    @Environment(ScheduleStore.self) private var schedule
    @State private var from = Date()
    @State private var to = Date()
    @State private var reason = ""
    @State private var employeeId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("leave.ask").frText(FRType.sectionHeader)
            if schedule.employees.count > 1 {
                Picker(selection: $employeeId) {
                    ForEach(schedule.employees) { e in
                        Text(verbatim: schedule.organizationName(for: e.id) ?? e.fullName).tag(Optional(e.id))
                    }
                } label: { Text("leave.employer") }
                .pickerStyle(.menu)
            }
            DatePicker(selection: $from, in: Date()..., displayedComponents: .date) { Text("leave.from") }
            DatePicker(selection: $to, in: from..., displayedComponents: .date) { Text("leave.to") }
            TextField(text: $reason, prompt: Text("leave.reason.placeholder")) { Text("leave.reason.placeholder") }
                .font(.system(size: 15))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
            if let error = leave.lastError {
                Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
            }
            Button {
                guard let id = employeeId ?? schedule.employees.first?.id else { return }
                Task {
                    if await leave.ask(employeeId: id, from: from, to: to, reason: reason) {
                        FRHaptic.success.fire()
                        dismiss()
                    } else {
                        FRHaptic.error.fire()
                    }
                }
            } label: {
                Text("leave.send")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .frCTAShadow()
            }
            .buttonStyle(.plain)
            .disabled(leave.busy)
            Spacer(minLength: 0)
        }
        .padding(20)
        .environment(\.locale, FRLanguage.locale)
        .background(Color.foodrun.background.ignoresSafeArea(edges: .bottom))
        .onAppear { employeeId = schedule.employees.first?.id }
        .onChange(of: from) { _, new in if to < new { to = new } }
    }
}
