import Foundation

// Codable structs for the Foodrun Supabase tables the worker app shares with the
// HQ dashboard (https://supabase.foodrun.nl). Field names match the database
// columns exactly — the HQ web code (src/hooks/useEmployeeHours.ts,
// useShiftClock.ts, useUrenOverview.ts) reads and writes the same rows.
//
// Re-verified against src/integrations/supabase/types.ts and the migrations on
// 2026-09-28. When a column changes, update this file AND SchemaContract.md.
//
// Conventions:
//  * Postgres `date` columns (work_date, start_date, …) stay `String`
//    ("YYYY-MM-DD") — they are calendar days, not instants. Use the `…Day`
//    helpers for display.
//  * `timestamptz` columns decode to `Date`.
//  * JSONB columns keep the JSON key spelling the web app writes
//    (`startTime` / `endTime`, camelCase).

// MARK: - employees

public struct DBEmployee: Codable, Identifiable, Hashable {
    public let id: UUID
    public let user_id: UUID            // operator (org owner) this row belongs to
    public let auth_user_id: UUID?      // the worker's auth user — one worker can have N rows (multi-operator)
    public let name: String
    public let last_name: String?
    public let email: String?
    public let phone: String?
    public let hourly_rate: Double?
    public let roles: [String]?
    public let contract_type: String?   // "eigenaar" | "ovo" | "ao" | …
    public let approval_status: String? // "pending" | "approved" | "declined" | "disconnected"
    public let onboarded_at: Date?

    public var fullName: String { [name, last_name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ") }
    public var isApproved: Bool { (approval_status ?? "approved") == "approved" }
}

// MARK: - activities (events / festivals the worker is rostered on)

/// One entry of `activities.daily_times` / `daily_employee_times` (JSONB).
public struct DBDayTimes: Codable, Hashable {
    public let startTime: String?       // "HH:mm"
    public let endTime: String?
    public let active: Bool?
}

public struct DBActivity: Codable, Identifiable, Hashable {
    public let id: UUID
    public let user_id: UUID            // operator that owns the activity
    public let name: String
    public let start_date: String       // "YYYY-MM-DD"
    public let end_date: String
    public let start_time: String?      // activity-wide default "HH:mm[:ss]"
    public let end_time: String?
    public let location: String?
    public let color: String?           // hex, data-driven (truck/event colour)
    public let food_truck: String?
    /// date → activity-wide window for that day
    public let daily_times: [String: DBDayTimes]?
    /// date → employee_id → personal window (overrides daily_times)
    public let daily_employee_times: [String: [String: DBDayTimes]]?
    /// date → employee ids rostered that day (the source of truth for "am I working")
    public let daily_employees: [String: [String]]?
    /// legacy: employee ids rostered for every day of the activity
    public let employees: [String]?
    /// date → how many people are rostered. Only filled by the worker feed
    /// (get_my_worker_activities), which hides who the colleagues are.
    public let crew_counts: [String: Int]?

    /// People rostered on `day`, including the caller: the worker feed's
    /// crew_counts when present, else counted from the roster (operator view).
    public func headcount(on day: String) -> Int {
        crew_counts?[day] ?? rosteredIds(on: day).count
    }

    /// Days this employee is rostered, same rule as scheduledDaysFor() in useEmployeeHours.ts.
    public func scheduledDays(for employeeId: UUID) -> [String] {
        let key = employeeId.uuidString.lowercased()
        if let daily = daily_employees {
            let days = daily.filter { $0.value.map { $0.lowercased() }.contains(key) }.map(\.key).sorted()
            if !days.isEmpty { return days }
        }
        guard (employees ?? []).map({ $0.lowercased() }).contains(key) else { return [] }
        return SchemaDates.days(from: start_date, to: end_date)
    }

    /// Employee ids (lower-case) rostered on `day`: daily_employees when the
    /// activity uses per-day rostering, else the legacy flat list for any day
    /// inside the activity's range.
    public func rosteredIds(on day: String) -> [String] {
        if let daily = daily_employees, !daily.isEmpty { return (daily[day] ?? []).map { $0.lowercased() } }
        guard day >= start_date, day <= end_date else { return [] }
        return (employees ?? []).map { $0.lowercased() }
    }

    /// Planned window for one employee on one day: personal override → day window → activity default.
    public func window(on day: String, for employeeId: UUID) -> (start: String, end: String)? {
        let personal = daily_employee_times?[day]?[employeeId.uuidString.lowercased()]
            ?? daily_employee_times?[day]?[employeeId.uuidString]
        let dayTimes = daily_times?[day]
        guard let s = personal?.startTime ?? dayTimes?.startTime ?? start_time,
              let e = personal?.endTime ?? dayTimes?.endTime ?? end_time else { return nil }
        return (String(s.prefix(5)), String(e.prefix(5)))
    }

    public static let selectColumns =
        "id, user_id, name, start_date, end_date, start_time, end_time, location, color, food_truck, daily_times, daily_employee_times, daily_employees, employees"
}

// MARK: - shift_clock_events (append-only clock stream, migration 20260908000000)
//
// Toggle semantics: the latest event's kind decides "am I on the clock?".
// `.in` / `.break_end` = yes, `.out` / `.break_start` = no. Workers only insert
// through the `clock_in` / `clock_out` RPCs, which stamp event_at server-side and
// set source = 'mobile' (the column's CHECK allows mobile | kiosk | manual | pos).

public enum ShiftClockKind: String, Codable {
    case `in`
    case out
    case break_start
    case break_end
}

public struct DBShiftClockEvent: Codable, Identifiable, Hashable {
    public let id: UUID
    public let employee_id: UUID
    public let activity_id: UUID
    public let kind: ShiftClockKind
    public let event_at: Date
    public let lat: Double?
    public let lng: Double?
    public let accuracy_m: Double?
    public let source: String
    public let created_at: Date
}

// MARK: - employee_hours (one row per employee × activity × day)
//
// Worker upserts with status 'pending' (unique on employee_id, activity_id,
// work_date — same as useMyHours().submit on the web). The operator approves or
// rejects in HQ → Stakeholders → Uren; the trigger
// notify_worker_on_hours_decision() then writes a worker_notifications row.

public enum HoursStatus: String, Codable {
    case pending, approved, rejected
}

public struct DBEmployeeHours: Codable, Identifiable, Hashable {
    public let id: UUID
    public let employee_id: UUID
    public let activity_id: UUID
    public let work_date: String        // "YYYY-MM-DD"
    public let hours: Double
    public let break_minutes: Int
    public let comment: String?
    public let status: HoursStatus
    public let submitted_at: Date?
    public let approved_by: UUID?
    public let approved_at: Date?
    public let rejected_reason: String?

    public var workDay: Date { SchemaDates.date(work_date) ?? Date() }
}

/// Insert/upsert payload — mirrors the object useMyHours().submit sends.
public struct DBEmployeeHoursUpsert: Encodable {
    public let employee_id: UUID
    public let activity_id: UUID
    public let work_date: String
    public let hours: Double
    public let break_minutes: Int
    public let comment: String?
    public let status: String = "pending"
    public let submitted_at: Date
    public let approved_by: UUID? = nil
    public let approved_at: Date? = nil
    public let rejected_reason: String? = nil
}

// MARK: - employee_availability (worker says when they can work)
//
// One row per employee × date (unique). Operators see it on HQ's scheduling
// board. `slots` are minute ranges (0–1440) — same shape as AvailabilitySlot in
// src/hooks/useMyAvailability.ts. `status` is the day's roll-up.

public struct DBAvailabilitySlot: Codable, Hashable {
    public let start: Int               // minutes from midnight
    public let end: Int
    public let status: String           // "available" | "unavailable"
}

public struct DBAvailability: Codable, Identifiable, Hashable {
    public let id: UUID
    public let employee_id: UUID
    public let date: String             // "YYYY-MM-DD"
    public let status: String           // "available" | "unavailable" | "maybe"
    public let note: String?
    public let slots: [DBAvailabilitySlot]?
    public let updated_at: Date?
}

public struct DBAvailabilityUpsert: Encodable {
    public let employee_id: UUID
    public let date: String
    public let status: String
    public let note: String?
    public let slots: [DBAvailabilitySlot]?
    public let updated_at: Date
}

// MARK: - worker_notifications (inbox)

/// Values of worker_notifications.type written by the DB triggers + edge functions
/// (see useWorkerInbox.ts on the web). Unknown values decode to `.other` so a new
/// server-side kind never breaks the inbox.
public enum WorkerNotificationKind: String, Codable {
    case hired, removed
    case activity_added, activity_updated
    case hours_approved, hours_rejected
    case approved, declined
    case other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = WorkerNotificationKind(rawValue: raw) ?? .other
    }
}

public struct DBWorkerNotification: Codable, Identifiable, Hashable {
    public let id: UUID
    public let user_id: UUID            // the worker's auth user
    public let activity_id: UUID?
    public let type: WorkerNotificationKind
    public let title: String
    public let body: String?
    public let url: String?
    public let is_read: Bool
    public let operator_name: String?
    public let created_at: Date
}

// MARK: - tasks (operator-owned; checklists live in the `checklists` JSONB)

public struct DBTaskChecklistItem: Codable, Hashable {
    public let id: String
    public let text: String
    public let done: Bool
}

public struct DBTaskChecklist: Codable, Hashable {
    public let id: String
    public let title: String
    public let items: [DBTaskChecklistItem]
}

public struct DBTask: Codable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let task_date: String?
    public let completed: Bool?
    public let assigned_employees: [String]?
    public let checklists: [DBTaskChecklist]?
}

/// UI model for one checklist line on the Tasks screen. Built from a DBTask's
/// checklist items (not a table of its own).
public struct DBTaskItem: Identifiable, Hashable {
    public let id: UUID
    public let task_id: UUID?
    public let title: String
    public let note: String?
    public let requires_value: Bool
    public let requires_photo: Bool
    public let value: String?
    public let photo_url: String?
    public let completed_at: Date?
    public let order: Int
}

// MARK: - Date helpers for `date` columns

public enum SchemaDates {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static func string(_ date: Date) -> String { formatter.string(from: date) }
    public static func date(_ day: String) -> Date? { formatter.date(from: String(day.prefix(10))) }

    public static func days(from start: String, to end: String) -> [String] {
        guard let s = date(start), let e = date(end), s <= e else { return [start] }
        var out: [String] = []
        var cursor = s
        let cal = Calendar(identifier: .gregorian)
        while cursor <= e {
            out.append(string(cursor))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return out
    }
}

// MARK: - Truck palette bridge

public enum TruckColor: String, CaseIterable, Codable {
    case mees, mike, mama, extraBlue

    public var hex: String {
        switch self {
        case .mees:      return "#FBE27A"
        case .mike:      return "#86EFAC"
        case .mama:      return "#F0A8C8"
        case .extraBlue: return "#7AA6F5"
        }
    }
}
