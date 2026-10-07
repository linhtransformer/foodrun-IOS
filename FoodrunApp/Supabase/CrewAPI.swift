import Foundation
import Supabase

// The crew-app calls: per-event script content, assigned tasks and stock
// counts. All four are login-scoped SECURITY DEFINER functions in the HQ
// migration 20261008120000_crew_app_event_content.sql — the app never uses
// the script/prep share tokens (bearer links that show everything).
//
// Answers and counts are stored next to the objects they're about
// (crew_task_responses / crew_stock_counts). Nothing here can change a
// product, a dish, the event's planned stock or activity_stock_updates.

enum CrewAPI {
    private static var client: SupabaseClient { SupabaseManager.shared.client }

    static func fetchEvent(activityId: UUID) async throws -> CrewEvent {
        try await client
            .rpc("get_my_event", params: ["p_activity_id": activityId.uuidString])
            .execute()
            .value
    }

    static func fetchTasks(from: String, to: String) async throws -> [CrewTaskOccurrence] {
        try await client
            .rpc("get_my_crew_tasks", params: ["p_from": from, "p_to": to])
            .execute()
            .value
    }

    /// Answer a task for one day. done=false with no value clears the answer.
    static func answer(taskId: UUID, day: String, done: Bool, number: Double? = nil, text: String? = nil) async throws {
        _ = try await client
            .rpc("submit_my_task_response",
                 params: AnswerParams(p_task_id: taskId, p_work_date: day, p_done: done,
                                      p_value_number: number, p_value_text: text))
            .execute()
    }

    /// Record a count of one event product (quantity nil = remove my count).
    static func count(activityId: UUID, day: String, productId: UUID, quantity: Double?, unitLevel: Int, note: String? = nil) async throws {
        _ = try await client
            .rpc("submit_my_stock_count",
                 params: CountParams(p_activity_id: activityId, p_count_date: day, p_product_id: productId,
                                     p_quantity: quantity, p_unit_level: unitLevel, p_note: note))
            .execute()
    }

    /// Server error codes raised by the functions → a line the worker understands.
    static func message(for error: Error) -> String {
        let raw = String(describing: error)
        for (code, key) in [
            ("not_on_crew", "crew.error.notOnCrew"),
            ("activity_closed", "crew.error.closed"),
            ("not_rostered_that_day", "crew.error.notThatDay"),
            ("value_required", "crew.error.valueRequired"),
            ("section_not_enabled", "crew.error.sectionOff"),
            ("negative_count", "crew.error.negative"),
        ] where raw.contains(code) {
            return FRLanguage.string(key)
        }
        return error.localizedDescription
    }
}

private struct AnswerParams: Encodable {
    let p_task_id: UUID
    let p_work_date: String
    let p_done: Bool
    let p_value_number: Double?
    let p_value_text: String?

    // Explicit nulls: PostgREST matches the function by argument names.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_task_id, forKey: .p_task_id)
        try c.encode(p_work_date, forKey: .p_work_date)
        try c.encode(p_done, forKey: .p_done)
        try c.encode(p_value_number, forKey: .p_value_number)
        try c.encode(p_value_text, forKey: .p_value_text)
    }
}

private struct CountParams: Encodable {
    let p_activity_id: UUID
    let p_count_date: String
    let p_product_id: UUID
    let p_quantity: Double?
    let p_unit_level: Int
    let p_note: String?

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_activity_id, forKey: .p_activity_id)
        try c.encode(p_count_date, forKey: .p_count_date)
        try c.encode(p_product_id, forKey: .p_product_id)
        try c.encode(p_quantity, forKey: .p_quantity)   // nil → null = clear
        try c.encode(p_unit_level, forKey: .p_unit_level)
        try c.encode(p_note, forKey: .p_note)
    }
}
