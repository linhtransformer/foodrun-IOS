import Foundation
import SwiftUI

// Schedule = the worker's employee rows + their operators' activities, folded
// into concrete shifts (activity × day × window). Same rules as the web worker
// portal: rostered days come from activities.daily_employees (legacy fallback:
// activities.employees = every day), the window from daily_employee_times →
// daily_times → the activity's start/end time. See DBActivity helpers in
// SharedSchema.swift and scheduledDaysFor() in src/hooks/useEmployeeHours.ts.
//
// Operators change the roster in HQ (Stakeholders → Rooster, or the admin
// "Add shift" sheet); `load()` picks it up.

/// One rostered shift for the signed-in worker.
public struct WorkerShift: Identifiable, Hashable {
    public var id: String { "\(activity.id.uuidString)|\(day)" }
    public let activity: DBActivity
    public let employee: DBEmployee     // this worker's row at the activity's operator
    public let day: String              // "YYYY-MM-DD"
    public let start: String?           // "HH:mm"
    public let end: String?
    /// What HQ put on this shift: pauze (minutes), opmerking, type, number of checklists.
    public var breakMinutes: Int? = nil
    public var note: String? = nil
    public var shiftType: String? = nil
    public var checklistCount: Int = 0

    public var date: Date { SchemaDates.date(day) ?? Date() }

    /// A shift at an employer the worker has left ("uit dienst"): history only.
    /// The server refuses clocking, swaps and availability there.
    public var isAtFormerEmployer: Bool { activity.left_on != nil }

    /// Whether hours can still be sent for this shift. Always at a current
    /// employer; at a former one only for days before leaving, up to 14 days
    /// after leaving — the server's employee_archived_guard (it counts from the
    /// moment of leaving; counting from the start of that day stays inside it).
    public func acceptsHours(now: Date = Date()) -> Bool {
        guard let leftOn = activity.left_on else { return true }
        guard day < String(leftOn.prefix(10)),
              let left = SchemaDates.date(leftOn),
              let deadline = Calendar(identifier: .gregorian).date(byAdding: .day, value: 14, to: left)
        else { return false }
        return now <= deadline
    }

    public var timeLabel: String {
        guard let start, let end else { return FRLanguage.string("shift.timeTBD") }
        return "\(start) – \(end)"
    }
    /// When the shift is over (Amsterdam time). An end before the start means it
    /// runs past midnight; no end time means the end of that day.
    public var endsAt: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        func minutes(_ t: String?) -> Int? {
            guard let t, t.count >= 5 else { return nil }
            return (Int(t.prefix(2)) ?? 0) * 60 + (Int(t.dropFirst(3).prefix(2)) ?? 0)
        }
        guard let end = minutes(end) else { return cal.date(byAdding: .day, value: 1, to: date) ?? date }
        let overnight = minutes(start).map { end <= $0 } ?? false
        return cal.date(byAdding: .minute, value: end + (overnight ? 1440 : 0), to: date) ?? date
    }
    public var plannedHours: Double {
        guard let start, let end else { return 0 }
        func m(_ t: String) -> Int { (Int(t.prefix(2)) ?? 0) * 60 + (Int(t.dropFirst(3).prefix(2)) ?? 0) }
        var mins = m(end) - m(start)
        if mins < 0 { mins += 1440 }
        // The planned pauze isn't worked time.
        mins = max(0, mins - (breakMinutes ?? 0))
        return Double(mins) / 60
    }
}

@MainActor
@Observable
public final class ScheduleStore {
    public var employees: [DBEmployee] = []
    public var activities: [DBActivity] = []
    public var selectedDate: Date = Date()
    public var weekOffset: Int = 0
    public var monthOffset: Int = 0
    public var monthOpen: Bool = false
    public var mode: ShiftsMode = .shifts
    public var heroExpanded: Bool = false          // bundle §State: starts false
    public var isLoading = false
    public var lastError: String?
    /// True when the last load fetched the roster. Change tracking only diffs
    /// real data, never the empty state a failed request leaves behind.
    public private(set) var rosterLoaded = false
    /// Operator (org owner) context — powers the admin "Add shift" sheet on the
    /// Roster tab. False for ordinary workers, and for an employer who switched
    /// "Werkgever-functies" off in Profile to use the app like their staff do.
    public var isOperator: Bool { hasOwnStaff && showsOperatorTools }
    /// The account has staff of its own (employees.user_id = me).
    public var hasOwnStaff = false
    /// Profile → "Werkgever-functies" (stored on the phone; on by default).
    public private(set) var showsOperatorTools: Bool = UserDefaults.standard.object(forKey: "showOperatorTools") as? Bool ?? true

    public func setShowsOperatorTools(_ on: Bool) {
        showsOperatorTools = on
        UserDefaults.standard.set(on, forKey: "showOperatorTools")
    }
    /// Organizations this account belongs to (RPC get_my_organizations; empty
    /// until the server offers it). Several when the worker works for more
    /// than one employer.
    public var organizations: [MyOrganization] = []

    /// The worker's rows at employers they have left ("uit dienst") whose past
    /// shifts the feed still returns (activities with `left_on`). Kept apart
    /// from `employees` so availability, leave and the like never reach them;
    /// only history (shifts, hours) uses them.
    public var formerEmployees: [DBEmployee] = []

    /// Employee rows whose hours the worker sees: current and former employers.
    public var historyEmployeeIds: [UUID] { (employees + formerEmployees).map(\.id) }

    /// Show which employer a shift is for only when there is more than one
    /// (a former employer counts: its past shifts are still listed).
    public var worksForSeveral: Bool {
        organizations.filter { $0.approval_status == "approved" || $0.isFormer }.count > 1
    }

    /// The organization behind one of the worker's employee rows.
    public func organizationName(for employeeId: UUID) -> String? {
        organizations.first { $0.employee_id == employeeId }?.name
    }
    public var operatorEmployees: [DBEmployee] = []
    public var operatorActivities: [DBActivity] = []
    /// "Today" for all date logic. Real clock in the app; pinned in previews so
    /// fixtures stay meaningful.
    public var today: Date = Date()
    /// True once the first load finished — until then we don't know whether the
    /// account is linked, so the "waiting for your employer" screen stays hidden.
    public var hasLoaded = false
    /// An employer row exists but still waits for their approval (web self-signup).
    public var hasPendingRequest = false

    /// Signed in, but no employer has added this account yet (and it isn't an
    /// operator using the app themselves).
    /// Someone who left every employer still gets their history, so a former
    /// employer with past shifts counts as linked.
    public var isUnlinked: Bool { hasLoaded && lastError == nil && employees.isEmpty && formerEmployees.isEmpty && !isOperator }

    public enum ShiftsMode: String, CaseIterable { case shifts, roster, availability }

    // MARK: - Loading

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        // Best-effort: a failure here just means no new links this time.
        try? await WorkerAPI.linkIdentity()
        do {
            let emps = try await WorkerAPI.fetchMyEmployees()
            let acts = try await WorkerAPI.fetchWorkerActivities()
            // Taken off the team in HQ (is_active = false) = no shifts from that employer.
            employees = emps.filter { $0.isApproved && $0.isActive }
            // Left an employer ("uit dienst"): the feed still sends past shifts
            // there, marked with left_on. Same row the server picks (oldest first).
            let current = Set(employees.map(\.user_id))
            let leftEmployers = Set(acts.filter { $0.left_on != nil }.map(\.user_id)).subtracting(current)
            var former: [DBEmployee] = []
            for e in emps where e.approval_status == "disconnected" && leftEmployers.contains(e.user_id)
                && !former.contains(where: { $0.user_id == e.user_id }) {
                former.append(e)
            }
            formerEmployees = former
            hasPendingRequest = emps.contains { $0.approval_status == "pending" }
            activities = acts
            lastError = nil
            rosterLoaded = true
            organizations = await WorkerAPI.fetchMyOrganizations()
        } catch {
            lastError = error.localizedDescription
            rosterLoaded = false
        }
        do {
            if let ctx = try await WorkerAPI.fetchOperatorContext() {
                hasOwnStaff = true
                operatorEmployees = ctx.employees
                operatorActivities = ctx.activities
            } else {
                hasOwnStaff = false
                operatorEmployees = []
                operatorActivities = []
            }
        } catch {
            lastError = error.localizedDescription
        }
        hasLoaded = true
    }

    // MARK: - Derived

    /// The worker's employee row at the operator who owns `activity`.
    public func employee(for activity: DBActivity) -> DBEmployee? {
        if activity.left_on != nil {
            return formerEmployees.first { $0.user_id == activity.user_id }
        }
        return employees.first { $0.user_id == activity.user_id }
    }

    /// Every rostered shift, oldest first.
    public var shifts: [WorkerShift] {
        activities.flatMap { activity -> [WorkerShift] in
            guard let emp = employee(for: activity) else { return [] }
            return activity.scheduledDays(for: emp.id).map { day in
                let w = activity.window(on: day, for: emp.id)
                let extras = activity.personalTimes(on: day, for: emp.id)
                let note = extras?.note?.trimmingCharacters(in: .whitespacesAndNewlines)
                let type = extras?.shiftType?.trimmingCharacters(in: .whitespacesAndNewlines)
                return WorkerShift(activity: activity, employee: emp, day: day, start: w?.start, end: w?.end,
                                   breakMinutes: (extras?.breakMinutes ?? 0) > 0 ? extras?.breakMinutes : nil,
                                   note: (note?.isEmpty ?? true) ? nil : note,
                                   shiftType: (type?.isEmpty ?? true) ? nil : type,
                                   checklistCount: extras?.checklistIds?.count ?? 0)
            }
        }
        .sorted { ($0.day, $0.start ?? "") < ($1.day, $1.start ?? "") }
    }

    /// Today and later — the "Still to work" list. Never a former employer's.
    public var upcomingShifts: [WorkerShift] {
        let todayKey = SchemaDates.string(today)
        return shifts.filter { $0.day >= todayKey && !$0.isAtFormerEmployer }
    }

    /// The hero card: first upcoming shift.
    public var nextShift: WorkerShift? { upcomingShifts.first }

    public func shift(activityId: UUID, day: String) -> WorkerShift? {
        shifts.first { $0.activity.id == activityId && $0.day == day }
    }

    public var shiftOnSelectedDay: DBActivity? { shiftOnSelectedDayFull?.activity }

    public var shiftOnSelectedDayFull: WorkerShift? {
        let key = SchemaDates.string(selectedDate)
        return shifts.first { $0.day == key }
    }

    public func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: today)
    }

    // MARK: - Preview

    public static let preview: ScheduleStore = {
        let s = ScheduleStore()
        s.employees = [Fixtures.worker]
        s.activities = [Fixtures.activityMees, Fixtures.activityMama]
        s.today = Fixtures.today
        s.selectedDate = Fixtures.today
        s.hasOwnStaff = true
        s.operatorEmployees = [Fixtures.worker]
        s.operatorActivities = [Fixtures.activityMees, Fixtures.activityMama]
        return s
    }()

    // MARK: - Formatting

    public static func iso(_ date: Date) -> String { SchemaDates.string(date) }
}
