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

    public var date: Date { SchemaDates.date(day) ?? Date() }
    public var timeLabel: String {
        guard let start, let end else { return "Tijd volgt" }
        return "\(start) – \(end)"
    }
    public var plannedHours: Double {
        guard let start, let end else { return 0 }
        func m(_ t: String) -> Int { (Int(t.prefix(2)) ?? 0) * 60 + (Int(t.dropFirst(3).prefix(2)) ?? 0) }
        var mins = m(end) - m(start)
        if mins < 0 { mins += 1440 }
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
    /// Operator (org owner) context — powers the admin "Add shift" sheet on the
    /// Roster tab. Empty / false for ordinary workers.
    public var isOperator = false
    public var operatorEmployees: [DBEmployee] = []
    public var operatorActivities: [DBActivity] = []
    /// "Today" for all date logic. Real clock in the app; pinned in previews so
    /// fixtures stay meaningful.
    public var today: Date = Date()

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
            employees = emps
            activities = acts
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        do {
            if let ctx = try await WorkerAPI.fetchOperatorContext() {
                isOperator = true
                operatorEmployees = ctx.employees
                operatorActivities = ctx.activities
            } else {
                isOperator = false
                operatorEmployees = []
                operatorActivities = []
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Derived

    /// The worker's employee row at the operator who owns `activity`.
    public func employee(for activity: DBActivity) -> DBEmployee? {
        employees.first { $0.user_id == activity.user_id }
    }

    /// Every rostered shift, oldest first.
    public var shifts: [WorkerShift] {
        activities.flatMap { activity -> [WorkerShift] in
            guard let emp = employee(for: activity) else { return [] }
            return activity.scheduledDays(for: emp.id).map { day in
                let w = activity.window(on: day, for: emp.id)
                return WorkerShift(activity: activity, employee: emp, day: day, start: w?.start, end: w?.end)
            }
        }
        .sorted { ($0.day, $0.start ?? "") < ($1.day, $1.start ?? "") }
    }

    /// Today and later — the "Still to work" list.
    public var upcomingShifts: [WorkerShift] {
        let todayKey = SchemaDates.string(today)
        return shifts.filter { $0.day >= todayKey }
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
        s.isOperator = true
        s.operatorEmployees = [Fixtures.worker]
        s.operatorActivities = [Fixtures.activityMees, Fixtures.activityMama]
        return s
    }()

    // MARK: - Formatting

    public static func iso(_ date: Date) -> String { SchemaDates.string(date) }
}
