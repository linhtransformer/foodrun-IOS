import SwiftUI

// Admin-only: tap someone in Shifts → Roster to change their times for that day
// or take them off it. Same columns HQ's scheduling board writes
// (WorkerAPI.setRosterTimes / removeFromRoster); the worker's app picks the
// change up on its next load and shows it as "Changed" (ShiftChangeStore).

struct RosterEntrySheet: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(\.dismiss) private var dismiss

    let employee: DBEmployee
    let activity: DBActivity
    let day: String

    @State private var start = Date()
    @State private var end = Date()
    @State private var saving = false
    @State private var confirmRemove = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: employee.fullName).font(.system(size: 22, weight: .bold))
                HStack(spacing: 6) {
                    Circle().fill(Color.foodrunData(hex: activity.color)).frame(width: 8, height: 8)
                    Text(verbatim: "\(activity.name) · \(dayLabel)")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }

            HStack(spacing: 10) {
                timeField("addShift.field.start", $start)
                timeField("addShift.field.end", $end)
            }

            if let error {
                Text(verbatim: error).font(.system(size: 12)).foregroundStyle(Color.foodrun.subject.destructive)
            }

            AuthPrimaryButton(title: "roster.edit.save", working: saving) {
                Task { await saveTimes() }
            }

            Button {
                confirmRemove = true
            } label: {
                Label("roster.edit.remove", systemImage: "person.badge.minus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.foodrun.subject.destructive)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(Capsule().stroke(Color.foodrun.subject.destructive, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(saving)

            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
        .onAppear(perform: prefill)
        .confirmationDialog(
            Text(verbatim: String(format: FRLanguage.string("roster.edit.removeConfirm %@ %@"), employee.fullName, dayLabel)),
            isPresented: $confirmRemove,
            titleVisibility: .visible
        ) {
            Button("roster.edit.remove", role: .destructive) {
                Task { await remove() }
            }
        }
    }

    private func timeField(_ label: LocalizedStringKey, _ value: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            DatePicker("", selection: value, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_GB"))   // always 24-hour
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
        }
    }

    // MARK: - Actions

    private func prefill() {
        guard let w = activity.window(on: day, for: employee.id) else { return }
        if let d = Self.parse(w.start) { start = d }
        if let d = Self.parse(w.end) { end = d }
    }

    private func saveTimes() async {
        saving = true
        defer { saving = false }
        do {
            try await WorkerAPI.setRosterTimes(activityId: activity.id, day: day, employeeId: employee.id,
                                               start: hhmm(start), end: hhmm(end))
            await schedule.load()
            FRHaptic.success.fire()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            FRHaptic.error.fire()
        }
    }

    private func remove() async {
        saving = true
        defer { saving = false }
        do {
            try await WorkerAPI.removeFromRoster(activityId: activity.id, day: day, employeeId: employee.id)
            await schedule.load()
            FRHaptic.warning.fire()
            dismiss()
        } catch {
            self.error = error.localizedDescription
            FRHaptic.error.fire()
        }
    }

    // MARK: - Helpers

    private var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: SchemaDates.date(day) ?? Date())
    }

    private func hhmm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func parse(_ t: String) -> Date? {
        let parts = t.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())
    }
}
