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

    /// Prep checklist + stock count per event and day, for the Tasks tab.
    static func fetchLists(from: String, to: String) async throws -> [CrewListEntry] {
        try await client
            .rpc("get_my_crew_lists", params: ["p_from": from, "p_to": to])
            .execute()
            .value
    }

    /// Answer a task for one day. done=false with no value clears the answer.
    static func answer(taskId: UUID, day: String, done: Bool, number: Double? = nil, text: String? = nil,
                       photoPath: String? = nil) async throws {
        _ = try await client
            .rpc("submit_my_task_response",
                 params: AnswerParams(p_task_id: taskId, p_work_date: day, p_done: done,
                                      p_value_number: number, p_value_text: text, p_photo_path: photoPath))
            .execute()
    }

    // MARK: - Photo tasks (private bucket crew-task-photos)

    static let photoBucket = "crew-task-photos"

    /// Uploads a JPEG under <activity>/<task>/<employee>/<timestamp>.jpg — the
    /// path the storage policy and submit_my_task_response insist on.
    static func uploadTaskPhoto(activityId: UUID, taskId: UUID, employeeId: UUID, jpeg: Data) async throws -> String {
        let path = [activityId, taskId, employeeId].map { $0.uuidString.lowercased() }.joined(separator: "/")
            + "/\(Int(Date().timeIntervalSince1970 * 1000)).jpg"
        _ = try await client.storage
            .from(photoBucket)
            .upload(path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: false))
        return path
    }

    /// Buckets anyone may read (heading photos/PDFs, setup photos, dish photos).
    private static let publicBuckets: Set<String> = ["script-heading-images", "script-heading-attachments", "dishes"]

    /// A link that opens a briefing file: public buckets directly, private ones
    /// (tickets, event files, my own files) through a short-lived signed URL —
    /// the server only signs files this crew member may see (crew_file_ok).
    static func fileURL(_ file: CrewFile) async throws -> URL {
        if publicBuckets.contains(file.bucket) {
            return try client.storage.from(file.bucket).getPublicURL(path: file.path)
        }
        return try await client.storage.from(file.bucket).createSignedURL(path: file.path, expiresIn: 600)
    }

    /// Public image URL for photos shown inline (no network round-trip).
    static func publicURL(_ file: CrewFile) -> URL? {
        try? client.storage.from(file.bucket).getPublicURL(path: file.path)
    }

    /// Short-lived link to show an uploaded photo.
    static func photoURL(_ path: String) async throws -> URL {
        try await client.storage.from(photoBucket).createSignedURL(path: path, expiresIn: 3600)
    }

    // MARK: - Prep checklist

    /// One prep item: tick/untick (checked), note (comment, "" clears) and/or
    /// the amount packed (quantity in units[unitLevel]; clearQuantity removes it).
    /// The amount lands in the prep checklist itself, so the portal shows it too.
    static func setPrepItem(activityId: UUID, key: String, checked: Bool?, comment: String?,
                            quantity: Double? = nil, unitLevel: Int? = nil, clearQuantity: Bool = false) async throws {
        _ = try await client
            .rpc("set_my_prep_item",
                 params: PrepParams(p_activity_id: activityId, p_key: key, p_checked: checked, p_comment: comment,
                                    p_quantity: quantity, p_unit_level: unitLevel, p_clear_quantity: clearQuantity))
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
            ("invalid_photo_path", "crew.error.photo"),
            ("invalid_item", "crew.error.prepItem"),
            ("prep_not_assigned", "crew.error.prepItem"),
            ("invalid_quantity", "crew.error.prepAmount"),
            ("invalid_unit", "crew.error.prepAmount"),
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
    let p_photo_path: String?

    // Declared by hand: a custom encode(to:) stops Swift synthesizing them.
    private enum CodingKeys: String, CodingKey {
        case p_task_id, p_work_date, p_done, p_value_number, p_value_text, p_photo_path
    }

    // Explicit nulls: PostgREST matches the function by argument names.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_task_id, forKey: .p_task_id)
        try c.encode(p_work_date, forKey: .p_work_date)
        try c.encode(p_done, forKey: .p_done)
        try c.encode(p_value_number, forKey: .p_value_number)
        try c.encode(p_value_text, forKey: .p_value_text)
        try c.encode(p_photo_path, forKey: .p_photo_path)
    }
}

private struct PrepParams: Encodable {
    let p_activity_id: UUID
    let p_key: String
    let p_checked: Bool?
    let p_comment: String?
    let p_quantity: Double?
    let p_unit_level: Int?
    let p_clear_quantity: Bool

    private enum CodingKeys: String, CodingKey {
        case p_activity_id, p_key, p_checked, p_comment, p_quantity, p_unit_level, p_clear_quantity
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_activity_id, forKey: .p_activity_id)
        try c.encode(p_key, forKey: .p_key)
        try c.encode(p_checked, forKey: .p_checked)
        try c.encode(p_comment, forKey: .p_comment)
        try c.encode(p_quantity, forKey: .p_quantity)
        try c.encode(p_unit_level, forKey: .p_unit_level)
        try c.encode(p_clear_quantity, forKey: .p_clear_quantity)
    }
}

private struct CountParams: Encodable {
    let p_activity_id: UUID
    let p_count_date: String
    let p_product_id: UUID
    let p_quantity: Double?
    let p_unit_level: Int
    let p_note: String?

    private enum CodingKeys: String, CodingKey {
        case p_activity_id, p_count_date, p_product_id, p_quantity, p_unit_level, p_note
    }

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
