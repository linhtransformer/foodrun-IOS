import Foundation
import Supabase

// Every Supabase call the worker app makes, in one place. Each function mirrors
// a web worker-portal hook so iOS and /me/* behave identically against the same
// rows — and whatever the operator does in HQ (Stakeholders → Uren, roster
// edits) shows up here on the next load.
//
//   linkIdentity       ↔ MeResolver → employee-identity-link edge fn
//   fetchMyEmployees   ↔ useMyHours().employeeQuery      (employees by auth_user_id)
//   fetchWorkerActivities ↔ useMyHours / useMyAvailability (RPC get_my_worker_activities)
//   fetchMyHours       ↔ useMyHours().hoursQuery         (employee_hours)
//   submitHours        ↔ useMyHours().submit             (upsert, status 'pending')
//   fetchInbox/markRead↔ useWorkerInbox                  (worker_notifications)
//   clock in/out       → ClockStore (RPCs clock_in / clock_out)
//   fetchClockEvents   ↔ useShiftClock                   (shift_clock_events, read-only)

enum WorkerAPI {
    private static var client: SupabaseClient { SupabaseManager.shared.client }

    static func currentUserId() async throws -> UUID {
        try await client.auth.session.user.id
    }

    /// Link this login to the employee rows the operator created for its email
    /// (sets employees.auth_user_id, adds the 'employee' role, clears the approval
    /// gate). The DB trigger only links when the account already exists at the
    /// moment the operator adds the employee; for the usual order — operator adds
    /// you, then you sign up — this edge function does it, exactly like the web's
    /// MeResolver on first /me visit. Idempotent, so calling it on every load is fine.
    static func linkIdentity() async throws {
        try await client.functions.invoke("employee-identity-link", options: FunctionInvokeOptions(method: .post))
    }

    /// All employee rows linked to this worker (one per operator), including ones
    /// still waiting for the operator's approval. Callers show shifts/hours for
    /// `isApproved` rows only — same filter the web applies.
    static func fetchMyEmployees() async throws -> [DBEmployee] {
        let uid = try await currentUserId()
        let rows: [DBEmployee] = try await client
            .from("employees")
            .select("id, user_id, auth_user_id, name, last_name, email, phone, hourly_rate, roles, contract_type, approval_status, onboarded_at")
            .eq("auth_user_id", value: uid.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows
    }

    /// The worker's activity feed (−60 … +60 days). Workers can't read the
    /// `activities` table (RLS); this operator-controlled function returns only
    /// activities they're rostered on or that the operator opened for
    /// availability, schedule fields only, `hide_name_from_workers` applied,
    /// roster reduced to this worker + per-day `crew_counts`. Same column names
    /// as the table, so it decodes into DBActivity.
    /// Migration 20260929120000_get_my_worker_activities.sql (HQ repo).
    static func fetchWorkerActivities() async throws -> [DBActivity] {
        let cal = Calendar(identifier: .gregorian)
        let from = SchemaDates.string(cal.date(byAdding: .day, value: -60, to: Date()) ?? Date())
        let to = SchemaDates.string(cal.date(byAdding: .day, value: 60, to: Date()) ?? Date())
        return try await client
            .rpc("get_my_worker_activities", params: ["p_from": from, "p_to": to])
            .execute()
            .value
    }

    /// Phone-tap clock events for one shift day, oldest first. The window runs to
    /// 06:00 the next morning so a late close still counts, without reaching the
    /// next day's shift of a multi-day activity.
    static func fetchClockEvents(employeeId: UUID, activityId: UUID, day: String) async throws -> [DBShiftClockEvent] {
        guard let start = SchemaDates.date(day) else { return [] }
        let iso = ISO8601DateFormatter()
        return try await client
            .from("shift_clock_events")
            .select("*")
            .eq("employee_id", value: employeeId.uuidString)
            .eq("activity_id", value: activityId.uuidString)
            .gte("event_at", value: iso.string(from: start))
            .lt("event_at", value: iso.string(from: start.addingTimeInterval(30 * 3600)))
            .order("event_at", ascending: true)
            .execute()
            .value
    }

    /// Operator-side: the operator's own activities straight from the table
    /// (owners have full read access). Used for the Roster "+" sheet.
    static func fetchOwnActivities(operatorId: UUID) async throws -> [DBActivity] {
        let cal = Calendar(identifier: .gregorian)
        let from = SchemaDates.string(cal.date(byAdding: .day, value: -60, to: Date()) ?? Date())
        let to = SchemaDates.string(cal.date(byAdding: .day, value: 60, to: Date()) ?? Date())
        return try await client
            .from("activities")
            .select(DBActivity.selectColumns)
            .eq("user_id", value: operatorId.uuidString)
            .gte("end_date", value: from)
            .lte("start_date", value: to)
            .order("start_date", ascending: true)
            .execute()
            .value
    }

    static func fetchMyHours(employeeIds: [UUID]) async throws -> [DBEmployeeHours] {
        guard !employeeIds.isEmpty else { return [] }
        return try await client
            .from("employee_hours")
            .select("id, employee_id, activity_id, work_date, hours, break_minutes, comment, status, submitted_at, approved_by, approved_at, rejected_reason")
            .in("employee_id", values: employeeIds.map(\.uuidString))
            .order("work_date", ascending: false)
            .execute()
            .value
    }

    /// Submit (or resubmit) hours for one day. Upsert on the same unique key the
    /// web uses, so a correction replaces the earlier row and resets it to
    /// 'pending' for the operator to review in HQ.
    static func submitHours(employeeId: UUID, activityId: UUID, workDate: String, hours: Double, breakMinutes: Int, comment: String?) async throws {
        let payload = DBEmployeeHoursUpsert(
            employee_id: employeeId,
            activity_id: activityId,
            work_date: workDate,
            hours: (hours * 100).rounded() / 100,
            break_minutes: breakMinutes,
            comment: comment,
            submitted_at: Date()
        )
        try await client
            .from("employee_hours")
            .upsert(payload, onConflict: "employee_id,activity_id,work_date")
            .execute()
    }

    static func fetchInbox() async throws -> [DBWorkerNotification] {
        let uid = try await currentUserId()
        return try await client
            .from("worker_notifications")
            .select("id, user_id, activity_id, type, title, body, url, is_read, operator_name, created_at")
            .eq("user_id", value: uid.uuidString)
            .order("created_at", ascending: false)
            .limit(100)
            .execute()
            .value
    }

    // MARK: - Availability (↔ useMyAvailability on the web)

    static func fetchAvailability(employeeIds: [UUID]) async throws -> [DBAvailability] {
        guard !employeeIds.isEmpty else { return [] }
        return try await client
            .from("employee_availability")
            .select("id, employee_id, date, status, note, slots, updated_at")
            .in("employee_id", values: employeeIds.map(\.uuidString))
            .execute()
            .value
    }

    /// Multi-operator fan-out: the same statement is written to every linked
    /// employee row so each operator sees it. `status == nil` clears the day.
    static func setAvailability(employeeIds: [UUID], date: String, status: String?, note: String?, slots: [DBAvailabilitySlot]?) async throws {
        guard !employeeIds.isEmpty else { return }
        guard let status else {
            try await client
                .from("employee_availability")
                .delete()
                .in("employee_id", values: employeeIds.map(\.uuidString))
                .eq("date", value: date)
                .execute()
            return
        }
        let now = Date()
        let rows = employeeIds.map {
            DBAvailabilityUpsert(employee_id: $0, date: date, status: status, note: note, slots: slots, updated_at: now)
        }
        try await client
            .from("employee_availability")
            .upsert(rows, onConflict: "employee_id,date")
            .execute()
    }

    // MARK: - Operator (admin) — roster edits from the phone

    /// Non-nil when the signed-in user plans shifts, i.e. has staff of their own
    /// (`employees.user_id = me`). Owning an organization is NOT the signal: the
    /// signup trigger (handle_new_user) gives every account — workers included —
    /// an auto-created workspace.
    static func fetchOperatorContext() async throws -> (employees: [DBEmployee], activities: [DBActivity])? {
        let uid = try await currentUserId()
        let employees: [DBEmployee] = try await client
            .from("employees")
            .select("id, user_id, auth_user_id, name, last_name, email, phone, hourly_rate, roles, contract_type, approval_status, onboarded_at")
            .eq("user_id", value: uid.uuidString)
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
        let staff = employees.filter(\.isApproved)
        guard !staff.isEmpty else { return nil }
        let activities = try await fetchOwnActivities(operatorId: uid)
        return (staff, activities)
    }

    /// Roster employees on one day of an activity with a personal window.
    /// Same writes as HQ's scheduling board (AvailabilityBoard.tsx): append to
    /// daily_employees[day], keep `employees` as the union of all days, and set
    /// daily_employee_times[day][employee] = { startTime, endTime }.
    static func addToRoster(activityId: UUID, day: String, employeeIds: [UUID], start: String, end: String) async throws {
        struct RosterRow: Decodable {
            let start_date: String
            let end_date: String
            let daily_employees: [String: [String]]?
            let daily_employee_times: [String: [String: DBDayTimes]]?
            let employees: [String]?
        }
        struct RosterUpdate: Encodable {
            let daily_employees: [String: [String]]
            let daily_employee_times: [String: [String: DBDayTimes]]
            let employees: [String]
        }
        let row: RosterRow = try await client
            .from("activities")
            .select("start_date, end_date, daily_employees, daily_employee_times, employees")
            .eq("id", value: activityId.uuidString)
            .single()
            .execute()
            .value

        var daily = row.daily_employees ?? [:]
        // Legacy activities keep the roster in the flat `employees` array (= every
        // day). Expand it first so switching to per-day doesn't drop anyone.
        if daily.isEmpty, let legacy = row.employees, !legacy.isEmpty {
            for d in SchemaDates.days(from: row.start_date, to: row.end_date) { daily[d] = legacy }
        }
        let ids = employeeIds.map { $0.uuidString.lowercased() }
        var dayIds = daily[day] ?? []
        for id in ids where !dayIds.contains(id) { dayIds.append(id) }
        daily[day] = dayIds

        var times = row.daily_employee_times ?? [:]
        var dayTimes = times[day] ?? [:]
        for id in ids { dayTimes[id] = DBDayTimes(startTime: start, endTime: end, active: nil) }
        times[day] = dayTimes

        let flat = Array(Set(daily.values.flatMap { $0 })).sorted()
        try await client
            .from("activities")
            .update(RosterUpdate(daily_employees: daily, daily_employee_times: times, employees: flat))
            .eq("id", value: activityId.uuidString)
            .execute()
    }

    static func markRead(_ id: UUID) async throws {
        try await client
            .from("worker_notifications")
            .update(["is_read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }
}
