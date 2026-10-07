import SwiftUI

// Operator-only sheet (Roster tab "+"): roster one or more employees on a day
// of an existing activity. Writes the same fields HQ's scheduling board writes
// (WorkerAPI.addToRoster → activities.daily_employees + daily_employee_times),
// so the shift appears in HQ → Stakeholders → Rooster and in each worker's app.

public struct AddShiftSheet: View {
    @Environment(TabRouter.self) private var router
    @Environment(ScheduleStore.self) private var schedule

    @State private var date: Date = Date()
    @State private var activityId: UUID?
    @State private var start: Date = AddShiftSheet.time(19, 0)
    @State private var end: Date = AddShiftSheet.time(23, 0)
    @State private var picks: Set<UUID> = []
    /// Days of the chosen activity to roster on — starts with the picked date.
    @State private var days: Set<String> = []
    @State private var isSaving = false
    @State private var error: String?

    public init() {}

    private var dayKey: String { SchemaDates.string(date) }

    /// Activities of this operator that run on the chosen day.
    private var activitiesOnDay: [DBActivity] {
        schedule.operatorActivities.filter { $0.start_date <= dayKey && dayKey <= $0.end_date }
    }

    private var selectedActivity: DBActivity? {
        activitiesOnDay.first { $0.id == activityId }
    }

    /// The chosen activity's days from today on (plus the picked date, even if past).
    private var activityDays: [String] {
        guard let a = selectedActivity else { return [] }
        let today = SchemaDates.string(schedule.today)
        return SchemaDates.days(from: a.start_date, to: a.end_date).filter { $0 >= today || $0 == dayKey }
    }

    /// On how many of the selected days this person is already rostered.
    private func rosteredDays(_ emp: DBEmployee) -> Int {
        guard let a = selectedActivity else { return 0 }
        let key = emp.id.uuidString.lowercased()
        return days.filter { a.rosteredIds(on: $0).contains(key) }.count
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                labeled("addShift.field.date") {
                    DatePicker("", selection: $date, displayedComponents: .date).labelsHidden()
                }
                activityField
                if activityDays.count > 1 { daysField }
                HStack(spacing: 10) {
                    labeled("addShift.field.start") {
                        DatePicker("", selection: $start, displayedComponents: .hourAndMinute).labelsHidden()
                    }
                    labeled("addShift.field.end") {
                        DatePicker("", selection: $end, displayedComponents: .hourAndMinute).labelsHidden()
                    }
                }
                crewField
                if let error {
                    Text(error).font(.system(size: 12)).foregroundStyle(Color.foodrun.subject.destructive)
                }
                actions
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(Color.foodrun.background.ignoresSafeArea())
        .onAppear { date = schedule.selectedDate; pickDefaultActivity(); days = [SchemaDates.string(schedule.selectedDate)] }
        .onChange(of: dayKey) { _, _ in pickDefaultActivity(); days = [dayKey] }
        .onChange(of: activityId) { _, _ in prefillTimes(); days = [dayKey] }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("addShift.title").frText(FRType.sectionHeader)
                Spacer()
                Text("addShift.adminBadge").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Text("addShift.description").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private var activityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("addShift.field.activity").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            if activitiesOnDay.isEmpty {
                Text("addShift.noActivity").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            FlowLayout(spacing: 8) {
                ForEach(activitiesOnDay) { a in
                    let on = a.id == activityId
                    Button {
                        activityId = a.id
                        FRHaptic.light.fire()
                    } label: {
                        HStack(spacing: 6) {
                            Circle().fill(Color.foodrunData(hex: a.color)).frame(width: 8, height: 8)
                            Text(verbatim: a.name).font(.system(size: 12.5, weight: .semibold))
                        }
                        .foregroundStyle(on ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                        .padding(.horizontal, 13).padding(.vertical, 9)
                        .background(Capsule().fill(on ? Color.foodrun.foreground : Color.foodrun.card))
                        .frNeu(.raised)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var daysField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("addShift.field.days").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Spacer()
                Button {
                    days = days.count == activityDays.count ? [dayKey] : Set(activityDays)
                    FRHaptic.light.fire()
                } label: {
                    Text(days.count == activityDays.count ? "addShift.days.one" : "addShift.days.all")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .underline()
                }
                .buttonStyle(.plain)
            }
            FlowLayout(spacing: 8) {
                ForEach(activityDays, id: \.self) { day in
                    let on = days.contains(day)
                    Button {
                        if on { if days.count > 1 { days.remove(day) } } else { days.insert(day) }
                        FRHaptic.light.fire()
                    } label: {
                        Text(verbatim: dayChip(day))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(on ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Capsule().fill(on ? Color.foodrun.foreground : Color.foodrun.card))
                            .frNeu(.raised)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
    }

    private func dayChip(_ day: String) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: SchemaDates.date(day) ?? Date())
    }

    private var crewField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("addShift.field.who").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Spacer()
                Text("addShift.pickCount \(picks.count)").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            VStack(spacing: 6) {
                ForEach(schedule.operatorEmployees) { emp in
                    let onDays = rosteredDays(emp)
                    // Disabled only when they're already on every selected day.
                    let rostered = !days.isEmpty && onDays == days.count
                    let on = picks.contains(emp.id)
                    Button {
                        if on { picks.remove(emp.id) } else { picks.insert(emp.id) }
                        FRHaptic.light.fire()
                    } label: {
                        HStack(spacing: 12) {
                            Text(verbatim: initials(emp.fullName))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color.foodrun.foreground)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color.foodrun.neuTrack))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: emp.fullName).frText(FRType.rowTitle)
                                if rostered {
                                    Text("addShift.alreadyRostered").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                } else if onDays > 0 {
                                    Text(verbatim: String(format: FRLanguage.string("addShift.partlyRostered %lld %lld"), onDays, days.count))
                                        .frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                            }
                            Spacer()
                            Image(systemName: on || rostered ? "checkmark.square.fill" : "square")
                                .foregroundStyle(on || rostered ? Color.foodrun.foreground : Color.foodrun.mutedForegroundSoft)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: FRRadius.listRowSm.value, style: .continuous)
                                .fill(on ? Color.foodrun.truck.mees.opacity(0.28) : Color.foodrun.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: FRRadius.listRowSm.value, style: .continuous)
                                .stroke(on ? Color.foodrun.foreground : .clear, lineWidth: 1.5)
                        )
                        .frNeu(.raised)
                        .opacity(rostered ? 0.6 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(rostered)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                Task { await save() }
            } label: {
                Text("addShift.save")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(Capsule().fill(canSave ? Color.foodrun.foreground : Color.foodrun.disabledInk))
                    .frCTAShadow()
            }
            .buttonStyle(.plain)
            .disabled(!canSave)

            Button {
                router.addShiftOpen = false
            } label: {
                Text("addShift.cancel").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 6)
    }

    // MARK: - Save

    private var canSave: Bool { !isSaving && selectedActivity != nil && !picks.isEmpty && !days.isEmpty }

    private func save() async {
        guard let activity = selectedActivity else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await WorkerAPI.addToRoster(
                activityId: activity.id,
                days: days.sorted(),
                employeeIds: Array(picks),
                start: hhmm(start),
                end: hhmm(end)
            )
            await schedule.load()
            FRHaptic.success.fire()
            router.addShiftOpen = false
        } catch {
            self.error = error.localizedDescription
            FRHaptic.error.fire()
        }
    }

    // MARK: - Helpers

    private func pickDefaultActivity() {
        if selectedActivity == nil { activityId = activitiesOnDay.first?.id }
        prefillTimes()
    }

    private func prefillTimes() {
        guard let a = selectedActivity else { return }
        let s = a.daily_times?[dayKey]?.startTime ?? a.start_time
        let e = a.daily_times?[dayKey]?.endTime ?? a.end_time
        if let s, let d = Self.parse(s) { start = d }
        if let e, let d = Self.parse(e) { end = d }
    }

    private func hhmm(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    private static func parse(_ t: String) -> Date? {
        let parts = t.split(separator: ":")
        guard parts.count >= 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return time(h, m)
    }

    private static func time(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    @ViewBuilder
    private func labeled<Content: View>(_ label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
        }
    }
}

#Preview("Add Shift sheet") {
    AddShiftSheet()
        .environment(TabRouter())
        .environment(ScheduleStore.preview)
        .background(Color.foodrun.background)
}
