import Foundation
import Supabase

// Ruilen (shift swaps and open shifts), verlof, the employer's availability rules and the
// shifts a worker wants per week. Same functions and tables as foodrun.nl/me — HQ migrations
// 20261017120000 + 121000 (swaps), 20261016170000 (leave), 20261017160000 (rules),
// 20261013100000 (wanted shifts), 20261022120000 (ask a colleague for a shift + the team
// roster). Every swap goes through a SECURITY DEFINER function that
// checks the caller is an approved employee of that employer; workers never read the table.

// MARK: - Swaps

public struct SwapActivity: Decodable, Hashable {
    public let id: UUID
    public let name: String
    public let food_truck: String?
    public let color: String?

    /// The truck / vestiging when there is one, else the event.
    public var title: String { food_truck ?? name }
}

/// One of my coming shifts on the board, with the request that runs on it.
public struct SwapShift: Decodable, Identifiable, Hashable {
    public let day: String
    /// The employer's name (20261017170000) — shown when the worker has several.
    public let employer: String?
    public let employee_id: UUID
    /// The employer account; colleagues carry the same owner_id.
    public let owner_id: UUID
    public let activity: SwapActivity
    public let window: DBDayTimes
    public let request: SwapShiftRequest?
    public var id: String { "\(activity.id.uuidString)|\(day)" }
}

public struct SwapShiftRequest: Decodable, Hashable {
    public let id: UUID
    public let status: String            // open | accepted
    public let to_name: String?
    public let taker_name: String?
}

/// A colleague offers a shift (to me, or to everyone).
public struct SwapOffer: Decodable, Identifiable, Hashable {
    public let id: UUID
    public let day: String
    public let employer: String?
    public let note: String?
    public let to_me: Bool
    public let activity: SwapActivity
    public let window: DBDayTimes
    public let from_name: String
}

/// A colleague asks to take over one of my shifts (kind 'ask'); I give it or keep it.
public struct SwapAsk: Decodable, Identifiable, Hashable {
    public let id: UUID
    public let day: String
    public let employer: String?
    public let note: String?
    public let activity: SwapActivity
    public let window: DBDayTimes
    public let taker_name: String
}

/// A shift with more places than people (daily_required_headcount).
public struct OpenShift: Decodable, Identifiable, Hashable {
    public let day: String
    public let employer: String?
    public let open: Int
    public let activity: SwapActivity
    public let window: DBDayTimes
    public let requested: Bool
    public var id: String { "\(activity.id.uuidString)|\(day)" }
}

/// A request I made or took part in.
public struct MySwapRequest: Decodable, Identifiable, Hashable {
    public let id: UUID
    public let employer: String?
    public let kind: String              // swap | pickup | ask
    public let status: String            // open | accepted | approved | declined | withdrawn
    public let day: String
    public let role: String              // giver | taker
    public let activity: SwapActivity
    public let window: DBDayTimes
    public let from_name: String?
    public let to_name: String?
    public let taker_name: String?
    public let note: String?
    public let manager_note: String?
}

public struct SwapColleague: Decodable, Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let color: String?
    public let owner_id: UUID
}

public struct SwapBoard: Decodable {
    public var mine: [MySwapRequest] = []
    public var offered: [SwapOffer] = []
    public var asked: [SwapAsk] = []
    public var open_shifts: [OpenShift] = []
    public var colleagues: [SwapColleague] = []
    public var my_shifts: [SwapShift] = []

    public init() {}

    private enum CodingKeys: String, CodingKey { case mine, offered, asked, open_shifts, colleagues, my_shifts }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mine = try c.decodeIfPresent([MySwapRequest].self, forKey: .mine) ?? []
        offered = try c.decodeIfPresent([SwapOffer].self, forKey: .offered) ?? []
        asked = try c.decodeIfPresent([SwapAsk].self, forKey: .asked) ?? []
        open_shifts = try c.decodeIfPresent([OpenShift].self, forKey: .open_shifts) ?? []
        colleagues = try c.decodeIfPresent([SwapColleague].self, forKey: .colleagues) ?? []
        my_shifts = try c.decodeIfPresent([SwapShift].self, forKey: .my_shifts) ?? []
    }
}

// MARK: - Team roster (get_my_team_roster: published shifts of my employers, colleagues by name)

public struct TeamShift: Decodable, Identifiable, Hashable {
    public struct Ask: Decodable, Hashable {
        public let id: UUID
        public let status: String        // open | accepted
    }

    public let day: String
    public let employee_id: UUID
    /// "Kim J" — first name and initial, like the swap board.
    public let name: String
    public let color: String?
    public let is_me: Bool
    public let employer: String?
    public let activity: SwapActivity
    public let window: DBDayTimes
    /// My running ask on this shift, if any.
    public let ask: Ask?
    public var id: String { "\(activity.id.uuidString)|\(day)|\(employee_id.uuidString)" }
}

// MARK: - Leave (leave_requests; the worker reads and asks, the employer decides)

public struct DBLeaveRequest: Decodable, Identifiable, Hashable {
    public let id: UUID
    public let employee_id: UUID
    public let start_date: String
    public let end_date: String
    public let start_time: String?
    public let end_time: String?
    public let reason: String?
    public let status: String            // pending | approved | rejected | cancelled
    public let manager_note: String?
}

// MARK: - Availability rules (get_my_availability_rules)

public struct MyAvailabilityRules: Decodable, Hashable {
    public struct Deadline: Decodable, Hashable {
        /// Day of the week as the server sends it: Wednesday arrives as 3 (JavaScript's
        /// 0 = Sunday, or ISO's 1 = Monday — both give 3). `daysAfterMonday` handles either.
        public let weekday: Int
        /// 0 = Monday … 6 = Sunday.
        public var daysAfterMonday: Int { (weekday + 6) % 7 }
        public let time: String          // "HH:mm"
        public let weeks_before: Int
    }

    public let owner_id: UUID
    public let employee_id: UUID
    public let organization_name: String
    public let reason_required: Bool
    public let deadline: Deadline?
    public let closed_days: [String]?

    /// When availability for the week starting `monday` closes (Amsterdam time), if it does.
    public func closesAt(weekStarting monday: Date) -> Date? {
        guard let deadline else { return nil }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        guard let day = cal.date(byAdding: .day, value: deadline.daysAfterMonday - 7 * deadline.weeks_before,
                                 to: cal.startOfDay(for: monday)) else { return nil }
        let parts = deadline.time.split(separator: ":").compactMap { Int($0) }
        return cal.date(bySettingHour: parts.first ?? 18, minute: parts.count > 1 ? parts[1] : 0, second: 0, of: day)
    }
}

enum PeopleAPI {
    private static var client: SupabaseClient { SupabaseManager.shared.client }

    // MARK: Swaps

    static func swapBoard() async throws -> SwapBoard {
        try await client.rpc("get_my_swap_board").execute().value
    }

    /// Offer one of my shifts to one colleague, or to everyone (colleague nil).
    static func offerShift(activityId: UUID, day: String, to colleague: UUID?, note: String?) async throws {
        _ = try await client
            .rpc("request_shift_swap", params: OfferParams(p_activity_id: activityId, p_day: day, p_to_employee_id: colleague, p_note: note))
            .execute()
    }

    /// Take over (accept) or turn down an offer. Returns approved | accepted | declined.
    static func respond(requestId: UUID, accept: Bool) async throws -> String {
        try await client
            .rpc("respond_shift_swap", params: RespondParams(p_request_id: requestId, p_accept: accept))
            .execute()
            .value
    }

    /// Ask for an open shift. Returns approved (it's mine) or accepted (the planner decides).
    static func requestOpenShift(activityId: UUID, day: String) async throws -> String {
        try await client
            .rpc("request_open_shift", params: OpenShiftParams(p_activity_id: activityId, p_day: day, p_note: nil))
            .execute()
            .value
    }

    /// Ask a colleague to let me take over their shift (take over only — nothing in return).
    static func askTakeover(activityId: UUID, day: String, from colleague: UUID, note: String?) async throws {
        _ = try await client
            .rpc("request_shift_takeover", params: TakeoverParams(p_activity_id: activityId, p_day: day, p_from_employee_id: colleague, p_note: note))
            .execute()
    }

    /// Everyone on the published roster of my employers between two days (max 31).
    static func teamRoster(from: String, to: String) async throws -> [TeamShift] {
        try await client.rpc("get_my_team_roster", params: ["p_from": from, "p_to": to]).execute().value
    }

    static func withdrawSwap(requestId: UUID) async throws {
        _ = try await client.rpc("withdraw_shift_swap", params: ["p_request_id": requestId.uuidString]).execute()
    }

    // MARK: Leave

    /// My own requests only: an employer account can read its staff's requests too.
    static func myLeave(employeeIds: [UUID]) async throws -> [DBLeaveRequest] {
        guard !employeeIds.isEmpty else { return [] }
        return try await client
            .from("leave_requests")
            .select("id, employee_id, start_date, end_date, start_time, end_time, reason, status, manager_note")
            .in("employee_id", values: employeeIds.map(\.uuidString))
            .order("start_date", ascending: false)
            .execute()
            .value
    }

    static func askLeave(employeeId: UUID, from: String, to: String, reason: String) async throws {
        try await client
            .from("leave_requests")
            .insert(LeaveInsert(employee_id: employeeId, start_date: from, end_date: to, reason: reason, status: "pending"))
            .execute()
    }

    static func withdrawLeave(id: UUID) async throws {
        try await client
            .from("leave_requests")
            .update(["status": "cancelled"])
            .eq("id", value: id.uuidString)
            .execute()
    }

    // MARK: Availability rules + wanted shifts

    static func availabilityRules() async throws -> [MyAvailabilityRules] {
        try await client.rpc("get_my_availability_rules").execute().value
    }

    static func wantedShifts(employeeIds: [UUID], weekStart: String) async throws -> Int? {
        guard !employeeIds.isEmpty else { return nil }
        struct Row: Decodable { let wanted_shifts: Int }
        let rows: [Row] = try await client
            .from("employee_week_preferences")
            .select("wanted_shifts")
            .in("employee_id", values: employeeIds.map(\.uuidString))
            .eq("week_start", value: weekStart)
            .limit(1)
            .execute()
            .value
        return rows.first?.wanted_shifts
    }

    /// Same number for every employer (one row per employee row), like availability.
    static func setWantedShifts(employeeIds: [UUID], weekStart: String, count: Int) async throws {
        guard !employeeIds.isEmpty else { return }
        struct Upsert: Encodable { let employee_id: UUID; let week_start: String; let wanted_shifts: Int }
        try await client
            .from("employee_week_preferences")
            .upsert(employeeIds.map { Upsert(employee_id: $0, week_start: weekStart, wanted_shifts: max(0, min(7, count))) },
                    onConflict: "employee_id,week_start")
            .execute()
    }

    /// The swap functions' error codes in the app's language.
    static func message(for error: Error) -> String {
        let raw = String(describing: error)
        for (code, key) in [
            ("already_requested", "swap.error.alreadyRequested"),
            ("already_on_shift", "swap.error.alreadyOnShift"),
            ("no_open_place", "swap.error.noOpenPlace"),
            ("not_open", "swap.error.notOpen"),
            ("in_the_past", "swap.error.inThePast"),
            ("not_on_shift", "swap.error.notOnShift"),
            ("unknown_colleague", "swap.error.unknownColleague"),
            ("shift_changed", "swap.error.shiftChanged"),
        ] where raw.contains(code) {
            return FRLanguage.string(key)
        }
        return error.localizedDescription
    }
}

private struct OfferParams: Encodable {
    let p_activity_id: UUID
    let p_day: String
    let p_to_employee_id: UUID?
    let p_note: String?

    private enum CodingKeys: String, CodingKey { case p_activity_id, p_day, p_to_employee_id, p_note }

    // Explicit nulls: PostgREST matches the function by argument names.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_activity_id, forKey: .p_activity_id)
        try c.encode(p_day, forKey: .p_day)
        try c.encode(p_to_employee_id, forKey: .p_to_employee_id)
        try c.encode(p_note, forKey: .p_note)
    }
}

private struct TakeoverParams: Encodable {
    let p_activity_id: UUID
    let p_day: String
    let p_from_employee_id: UUID
    let p_note: String?

    private enum CodingKeys: String, CodingKey { case p_activity_id, p_day, p_from_employee_id, p_note }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_activity_id, forKey: .p_activity_id)
        try c.encode(p_day, forKey: .p_day)
        try c.encode(p_from_employee_id, forKey: .p_from_employee_id)
        try c.encode(p_note, forKey: .p_note)
    }
}

private struct RespondParams: Encodable {
    let p_request_id: UUID
    let p_accept: Bool
}

private struct OpenShiftParams: Encodable {
    let p_activity_id: UUID
    let p_day: String
    let p_note: String?

    private enum CodingKeys: String, CodingKey { case p_activity_id, p_day, p_note }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_activity_id, forKey: .p_activity_id)
        try c.encode(p_day, forKey: .p_day)
        try c.encode(p_note, forKey: .p_note)
    }
}

private struct LeaveInsert: Encodable {
    let employee_id: UUID
    let start_date: String
    let end_date: String
    let reason: String
    let status: String
}
