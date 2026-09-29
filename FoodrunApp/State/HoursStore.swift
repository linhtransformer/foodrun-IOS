import Foundation
import SwiftUI

// The worker's own employee_hours rows + submit. Same table and upsert key the
// web /me/hours page uses; the operator approves/rejects them in HQ →
// Stakeholders → Uren, and the decision comes back here (status) and in the
// inbox (worker_notifications, written by the DB trigger).

@MainActor
@Observable
public final class HoursStore {
    public var rows: [DBEmployeeHours] = []
    public var hoursMonthOffset: Int = 0
    public var isLoading = false
    public var isSubmitting = false
    public var lastError: String?

    public var approvedMonthTotal: Double {
        rows.filter { $0.status == .approved && isInShownMonth($0) }.map(\.hours).reduce(0, +)
    }

    public var pendingMonthTotal: Double {
        rows.filter { $0.status == .pending && isInShownMonth($0) }.map(\.hours).reduce(0, +)
    }

    /// Oldest row still waiting for the operator (pending), or bounced back (rejected).
    public var pendingRow: DBEmployeeHours? {
        rows.filter { $0.status != .approved }.sorted { $0.work_date < $1.work_date }.first
    }

    public var shownMonth: Date {
        Calendar.current.date(byAdding: .month, value: hoursMonthOffset, to: Date()) ?? Date()
    }

    private func isInShownMonth(_ row: DBEmployeeHours) -> Bool {
        Calendar.current.isDate(row.workDay, equalTo: shownMonth, toGranularity: .month)
    }

    public func row(activityId: UUID, day: String) -> DBEmployeeHours? {
        rows.first { $0.activity_id == activityId && $0.work_date == day }
    }

    // MARK: - Live data

    public func load(employeeIds: [UUID]) async {
        isLoading = true
        defer { isLoading = false }
        do {
            rows = try await WorkerAPI.fetchMyHours(employeeIds: employeeIds)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Submit or correct one day's hours. Resets status to pending for review.
    @discardableResult
    public func submit(shift: WorkerShift, hours: Double, breakMinutes: Int, comment: String?) async -> Bool {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await WorkerAPI.submitHours(
                employeeId: shift.employee.id,
                activityId: shift.activity.id,
                workDate: shift.day,
                hours: hours,
                breakMinutes: breakMinutes,
                comment: comment
            )
            await load(employeeIds: Array(Set(rows.map(\.employee_id) + [shift.employee.id])))
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    // MARK: - Preview

    public static let preview: HoursStore = {
        let s = HoursStore()
        s.rows = [
            Fixtures.hoursPending,
            DBEmployeeHours(
                id: UUID(), employee_id: Fixtures.worker.id, activity_id: Fixtures.activityMees.id,
                work_date: SchemaDates.string(Fixtures.calendar.date(byAdding: .day, value: -5, to: Fixtures.today) ?? Fixtures.today),
                hours: 4.0, break_minutes: 0, comment: nil, status: .approved,
                submitted_at: Fixtures.today, approved_by: nil, approved_at: Fixtures.today, rejected_reason: nil
            ),
            DBEmployeeHours(
                id: UUID(), employee_id: Fixtures.worker.id, activity_id: Fixtures.activityMees.id,
                work_date: SchemaDates.string(Fixtures.calendar.date(byAdding: .day, value: -8, to: Fixtures.today) ?? Fixtures.today),
                hours: 6.0, break_minutes: 30, comment: nil, status: .approved,
                submitted_at: Fixtures.today, approved_by: nil, approved_at: Fixtures.today, rejected_reason: nil
            ),
        ]
        return s
    }()
}
