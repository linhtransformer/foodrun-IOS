import SwiftUI

// Bundle §2b. Who works on the day picked in the carousel.
//
// Workers can only read their own employee row (RLS), so they see themselves
// plus a headcount from activities.daily_employees. Operators (org owners) see
// every rostered person by name and get the "+" to roster someone — the same
// daily_employees / daily_employee_times fields HQ's scheduling board edits.

struct RosterMode: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(TabRouter.self) private var router
    /// Admin: the rostered person being edited (times / remove).
    @State private var editing: Entry?

    private var dayKey: String { SchemaDates.string(schedule.selectedDate) }

    /// The signed-in person's own shifts on the selected day, at every employer
    /// (one employee row per organization — a worker can work for several).
    private var myShiftsToday: [WorkerShift] {
        schedule.shifts.filter { $0.day == dayKey }
    }

    /// Own shifts the operator roster below doesn't cover: shifts at another
    /// employer, or an own row that isn't on the operator's staff list.
    private var myShiftsOutsideOperatorRoster: [WorkerShift] {
        guard schedule.isOperator else { return myShiftsToday }
        let covered = Set(operatorEntries.map(\.id))
        return myShiftsToday.filter { !covered.contains(Self.entryId($0.activity.id, $0.employee.id.uuidString)) }
    }

    /// Operator (own company): everyone rostered, by name, editable.
    private var operatorEntries: [Entry] {
        guard schedule.isOperator else { return [] }
        let names = Dictionary(schedule.operatorEmployees.map { ($0.id.uuidString.lowercased(), $0) }, uniquingKeysWith: { a, _ in a })
        let myIds = Set(schedule.employees.map { $0.id.uuidString.lowercased() })
        return schedule.operatorActivities.flatMap { activity -> [Entry] in
            activity.rosteredIds(on: dayKey).compactMap { id in
                guard let emp = names[id] else { return nil }
                let w = activity.window(on: dayKey, for: emp.id)
                return Entry(id: Self.entryId(activity.id, id), employee: emp, activity: activity,
                             time: w?.start ?? "", isYou: myIds.contains(id), editable: true)
            }
        }
    }

    /// Rows for the selected day: the operator roster (if any) plus the
    /// signed-in person's own shifts, so "you" is always listed.
    private var entries: [Entry] {
        let mine = myShiftsOutsideOperatorRoster.map { s in
            Entry(id: Self.entryId(s.activity.id, s.employee.id.uuidString), employee: s.employee,
                  activity: s.activity, time: s.start ?? "", isYou: true, editable: false)
        }
        return (operatorEntries + mine)
            .sorted { ($0.time, $0.employee.fullName) < ($1.time, $1.employee.fullName) }
    }

    /// Colleagues on the person's own shifts that can't be shown by name
    /// (workers only read their own employee row — RLS).
    private var hiddenColleagues: Int {
        // The operator's own activities already list everyone by name.
        let ownActivities = Set(schedule.isOperator ? schedule.operatorActivities.map(\.id) : [])
        return myShiftsOutsideOperatorRoster
            .filter { !ownActivities.contains($0.activity.id) }
            .reduce(0) { sum, s in sum + max(0, s.activity.headcount(on: dayKey) - 1) }
    }

    private static func entryId(_ activityId: UUID, _ employeeId: String) -> String {
        "\(activityId.uuidString.lowercased())|\(employeeId.lowercased())"
    }

    private var headcount: Int { entries.count + hiddenColleagues }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: dayLabel).frText(FRType.sectionHeader)
                    Text("roster.peopleOnShift \(headcount)")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                Spacer()
                if schedule.isOperator {
                    Button {
                        router.addShiftOpen = true
                        FRHaptic.medium.fire()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.foodrun.backgroundInverseInk)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.foodrun.foreground))
                            .frCTAShadow()
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("roster.addShift"))
                }
            }
            if schedule.isOperator {
                // Says why everyone is listed, and where the switch lives.
                Button { router.tab = .me } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "briefcase")
                        Text("roster.operatorView")
                            .frText(FRType.rowSubtitle)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if entries.isEmpty {
                Text("roster.empty")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                            .strokeBorder(Color.foodrun.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }
            VStack(spacing: 8) {
                ForEach(entries) { e in
                    let row = FRRosterRow(
                        name: e.employee.fullName,
                        initials: initials(e.employee.fullName),
                        avatarColor: Color.foodrunData(hex: e.employee.color ?? e.activity.color),
                        role: e.employee.roles?.first ?? "",
                        truckName: e.activity.food_truck ?? e.activity.name,
                        truckColor: Color.foodrunData(hex: e.activity.color),
                        time: e.time,
                        isYou: e.isYou
                    )
                    if schedule.isOperator && e.editable {
                        Button { editing = e } label: { row.contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                            .accessibilityHint(Text("roster.edit.hint"))
                    } else {
                        row
                    }
                }
                if hiddenColleagues > 0 {
                    Text("detail.crew.others \(hiddenColleagues)")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
        }
        .sheet(item: $editing) { e in
            RosterEntrySheet(employee: e.employee, activity: e.activity, day: dayKey)
        }
    }

    private struct Entry: Identifiable, Hashable {
        let id: String
        let employee: DBEmployee
        let activity: DBActivity
        let time: String
        let isYou: Bool
        /// Only the operator's own company's roster can be edited from here.
        let editable: Bool
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: schedule.selectedDate)
    }
}
