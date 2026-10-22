import SwiftUI

// Bundle §2b. Who works on the day picked in the carousel.
//
// Workers see the published roster of their employer(s) by name (get_my_team_roster) and the
// day's open shifts. Tapping a colleague's shift opens it view-only (ColleagueShiftView), where
// they can ask to take it over; the answer comes through the Inbox. Operators (org owners) see their
// own company's roster editable and get the "+" — the same daily_employees /
// daily_employee_times fields HQ's scheduling board edits. If the team roster can't load,
// workers fall back to their own shifts plus a headcount.

struct RosterMode: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(TabRouter.self) private var router
    @Environment(SwapStore.self) private var swaps
    /// Admin: the rostered person being edited (times / remove).
    @State private var editing: Entry?

    private var dayKey: String { SchemaDates.string(schedule.selectedDate) }

    /// The signed-in person's own shifts on the selected day, at every employer
    /// (one employee row per organization — a worker can work for several).
    private var myShiftsToday: [WorkerShift] {
        schedule.shifts.filter { $0.day == dayKey }
    }

    /// Own shifts the operator roster below doesn't cover: shifts at another
    /// employer, or an own row that isn't on the operator's staff list. Empty when
    /// the team roster lists those shifts instead (operatorTeam).
    private var myShiftsOutsideOperatorRoster: [WorkerShift] {
        guard schedule.isOperator else { return myShiftsToday }
        guard !operatorSeesTeam else { return [] }
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

    private var headcount: Int {
        if showsTeam { return teamToday.count }
        return entries.count + (operatorSeesTeam ? operatorTeam.count : hiddenColleagues)
    }

    /// The operator's own company's activities: edited from operatorEntries.
    private var ownActivityIds: Set<UUID> {
        schedule.isOperator ? Set(schedule.operatorActivities.map(\.id)) : []
    }

    /// Operator who also works elsewhere: the team roster fills in the other employers.
    private var operatorSeesTeam: Bool { AppConfig.Features.shiftSwaps && schedule.isOperator && swaps.teamLoaded }

    /// Operator view: everyone on the day's shifts at the other employers, by name.
    private var operatorTeam: [TeamShift] {
        guard operatorSeesTeam else { return [] }
        return teamToday.filter { !ownActivityIds.contains($0.activity.id) }
    }

    /// Worker view with the team roster loaded (swaps switched on).
    private var showsTeam: Bool { AppConfig.Features.shiftSwaps && !schedule.isOperator && swaps.teamLoaded }

    private var teamToday: [TeamShift] {
        swaps.team(on: dayKey).sorted { ($0.window.startTime ?? "", $0.name) < ($1.window.startTime ?? "", $1.name) }
    }

    private var openToday: [OpenShift] {
        guard AppConfig.Features.shiftSwaps else { return [] }
        return swaps.openShifts(on: dayKey).filter { !ownActivityIds.contains($0.activity.id) }
    }

    /// Monday of the selected week: the team roster loads a week at a time.
    private var weekKey: String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        return SchemaDates.string(cal.dateInterval(of: .weekOfYear, for: schedule.selectedDate)?.start ?? schedule.selectedDate)
    }

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
            if showsTeam {
                teamList
            } else {
                operatorList
            }
            if !openToday.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("swaps.section.open").frText(FRType.sectionHeader).padding(.top, 6)
                    ForEach(openToday) { openRow($0) }
                }
            }
        }
        .sheet(item: $editing) { e in
            RosterEntrySheet(employee: e.employee, activity: e.activity, day: dayKey)
        }
        .task(id: "\(weekKey)|\(schedule.isOperator)") {
            // Operators too: their shifts at other employers list colleagues from it.
            guard AppConfig.Features.shiftSwaps else { return }
            await swaps.loadTeam(around: schedule.selectedDate)
        }
    }

    // MARK: - Worker: the whole published roster

    @ViewBuilder
    private var teamList: some View {
        if teamToday.isEmpty && openToday.isEmpty {
            emptyBox
        }
        VStack(spacing: 8) {
            ForEach(teamToday) { teamRow($0) }
        }
    }

    private func teamRow(_ t: TeamShift) -> some View {
        Button {
            if t.is_me {
                if let date = SchemaDates.date(t.day) {
                    router.pushOnShifts(.shiftDetail(activityId: t.activity.id, date: date))
                }
            } else {
                router.pushOnShifts(.colleagueShift(t))
                FRHaptic.light.fire()
            }
        } label: {
            VStack(alignment: .trailing, spacing: 4) {
                FRRosterRow(
                    name: t.name,
                    initials: initials(t.name),
                    avatarColor: Color.foodrunData(hex: t.color ?? t.activity.color),
                    role: schedule.worksForSeveral ? (t.employer ?? "") : "",
                    truckName: t.activity.title,
                    truckColor: Color.foodrunData(hex: t.activity.color),
                    time: PeopleFormat.window(t.window),
                    isYou: t.is_me
                )
                if t.ask != nil {
                    Text("swaps.requested")
                        .frText(FRType.fieldLabel)
                        .foregroundStyle(Color.foodrun.subject.warning)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(t.is_me ? Text("roster.openMine.hint") : Text("roster.view.hint"))
    }

    private func openRow(_ open: OpenShift) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Circle().fill(Color.foodrunData(hex: open.activity.color)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: open.activity.title).frText(FRType.rowTitle).lineLimit(1)
                Text(verbatim: PeopleFormat.window(open.window))
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Text("swaps.openPlaces \(open.open)").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.positive)
            }
            Spacer(minLength: 8)
            if open.requested {
                Text("swaps.requested").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.subject.warning)
            } else {
                Button {
                    Task { if await swaps.pickUp(open) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } }
                } label: {
                    Text("swaps.iWantThis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.foodrun.backgroundInverseInk)
                        .padding(.horizontal, 14).frame(minHeight: 36)
                        .background(Capsule().fill(Color.foodrun.foreground))
                }
                .buttonStyle(.plain)
                .disabled(swaps.busy)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private var emptyBox: some View {
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

    // MARK: - Operator (and the fallback without the team roster)

    @ViewBuilder
    private var operatorList: some View {
        if entries.isEmpty && operatorTeam.isEmpty && openToday.isEmpty {
            emptyBox
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
            ForEach(operatorTeam) { teamRow($0) }
            if !operatorSeesTeam && hiddenColleagues > 0 {
                Text("detail.crew.others \(hiddenColleagues)")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
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
