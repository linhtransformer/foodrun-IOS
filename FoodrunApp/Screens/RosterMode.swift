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

    private var dayKey: String { SchemaDates.string(schedule.selectedDate) }

    /// Rows for the selected day.
    private var entries: [Entry] {
        if schedule.isOperator {
            let names = Dictionary(uniqueKeysWithValues: schedule.operatorEmployees.map { ($0.id.uuidString.lowercased(), $0) })
            let myIds = Set(schedule.employees.map { $0.id.uuidString.lowercased() })
            return schedule.operatorActivities.flatMap { activity -> [Entry] in
                activity.rosteredIds(on: dayKey).compactMap { id in
                    guard let emp = names[id] else { return nil }
                    let w = activity.window(on: dayKey, for: emp.id)
                    return Entry(id: "\(activity.id)|\(id)", employee: emp, activity: activity, time: w?.start ?? "", isYou: myIds.contains(id))
                }
            }
            .sorted { ($0.time, $0.employee.fullName) < ($1.time, $1.employee.fullName) }
        }
        guard let mine = schedule.shiftOnSelectedDayFull else { return [] }
        return [Entry(id: mine.id, employee: mine.employee, activity: mine.activity, time: mine.start ?? "", isYou: true)]
    }

    /// Colleagues a worker can't see by name.
    private var hiddenColleagues: Int {
        guard !schedule.isOperator, let mine = schedule.shiftOnSelectedDayFull else { return 0 }
        return max(0, mine.activity.headcount(on: dayKey) - 1)
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
                    FRRosterRow(
                        name: e.employee.fullName,
                        initials: initials(e.employee.fullName),
                        avatarColor: Color.foodrunData(hex: e.activity.color),
                        role: e.employee.roles?.first ?? "",
                        truckName: e.activity.food_truck ?? e.activity.name,
                        truckColor: Color.foodrunData(hex: e.activity.color),
                        time: e.time,
                        isYou: e.isYou
                    )
                }
                if hiddenColleagues > 0 {
                    Text("detail.crew.others \(hiddenColleagues)")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
        }
    }

    private struct Entry: Identifiable {
        let id: String
        let employee: DBEmployee
        let activity: DBActivity
        let time: String
        let isYou: Bool
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private var dayLabel: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = .autoupdatingCurrent
        return f.string(from: schedule.selectedDate)
    }
}
