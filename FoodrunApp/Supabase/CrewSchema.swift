import Foundation

// Shapes returned by the crew-app RPCs (HQ migration
// 20261008120000_crew_app_event_content.sql):
//   get_my_event(p_activity_id)        → CrewEvent
//   get_my_crew_tasks(p_from, p_to)    → [CrewTaskOccurrence]
// Same conventions as SharedSchema.swift: field names = JSON keys, dates as
// "YYYY-MM-DD" strings. Timestamps stay strings here — they come out of
// to_jsonb() inside the function and are only shown, never compared.
//
// The operator decides per crew member which sections come back
// (crew_section_access). A missing section = nil, so views only render what
// the operator switched on. Tasks assigned to the caller always come back.

public struct CrewEvent: Decodable {
    public let activity: CrewEventActivity
    public let employee_id: UUID
    public let my_days: [String]
    public let sections: [String]
    public let briefing: CrewBriefing?
    public let dishes: [CrewDish]?
    public let prep: CrewPrep?
    public let stock: CrewStock?
    public let tasks: [CrewTask]

    public func has(_ section: CrewEventSection) -> Bool {
        section == .tasks || sections.contains(section.rawValue)
    }
}

/// Sections of the event screen. `tasks` isn't an operator toggle — assigned
/// tasks are always visible to their assignee.
public enum CrewEventSection: String, CaseIterable, Identifiable {
    case tasks, briefing, dishes, prep, stock
    public var id: String { rawValue }
}

public struct CrewEventActivity: Decodable, Hashable {
    public let id: UUID
    public let name: String
    public let start_date: String?
    public let end_date: String?
    public let location: String?
    public let food_truck: String?
    public let color: String?
    public let is_closed: Bool
}

public struct CrewBriefing: Decodable, Hashable {
    public let headings: [CrewHeading]
    public let notes: [CrewNote]
}

public struct CrewHeading: Decodable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let content: String?
}

/// The operator's per-person note for one day (scripts.employee_timestamps).
public struct CrewNote: Decodable, Hashable {
    public let date: String
    public let start_time: String?
    public let end_time: String?
    public let comment: String?
}

public struct CrewDish: Decodable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let recipe: String?
    public let serving_size: Double?
    public let estimated_quantity: Double?
    public let ingredients: [CrewIngredient]
}

/// Per-serving amount in the unit the operator chose for the dish.
public struct CrewIngredient: Decodable, Hashable, Identifiable {
    public let product_id: UUID
    public let name: String
    public let quantity: Double
    public let unit: String?
    public var id: UUID { product_id }
}

/// Read-only prep list. `checked` is what packers ticked in the prep portal.
public struct CrewPrep: Decodable, Hashable {
    public let updated_at: String?
    public let items: [CrewPrepItem]
}

public struct CrewPrepItem: Decodable, Hashable, Identifiable {
    public let key: String          // ing-/equip-/addon-<productId>, same keys as the portal
    public let section: String      // ingredients | equipment | rentals | addons
    public let product_id: UUID
    public let name: String
    public let quantity: Double
    public let unit: String?
    public let checked: Bool
    public var id: String { key }
}

public struct CrewStock: Decodable, Hashable {
    public let products: [CrewStockProduct]
    public let my_counts: [CrewStockCount]
}

public struct CrewStockProduct: Decodable, Hashable, Identifiable {
    public let product_id: UUID
    public let name: String
    public let type: String?
    public let planned_quantity: Double   // at units[0]
    public let units: [String]            // unit chain, outermost first
    public var id: UUID { product_id }
}

public struct CrewStockCount: Decodable, Hashable {
    public let count_date: String
    public let product_id: UUID
    public let quantity: Double
    public let unit_level: Int
    public let note: String?
    public let counted_at: String?
}

public enum CrewTaskKind: String, Decodable, Hashable {
    case check, count, number, text, other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CrewTaskKind(rawValue: raw) ?? .other
    }

    /// Kinds answered with a value rather than a tick.
    public var asksValue: Bool { self == .count || self == .number || self == .text }
}

public struct CrewTask: Decodable, Hashable, Identifiable {
    public let id: UUID
    public let activity_id: UUID
    public let work_date: String?        // nil = every day of the event
    public let title: String
    public let instructions: String?
    public let kind: CrewTaskKind
    public let unit_level: Int?
    public let unit: String?             // resolved unit for a product count
    public let for_everyone: Bool
    public let product: CrewTaskProduct?
    public let dish: CrewDish?
    public let responses: [CrewTaskResponse]?   // absent in get_my_crew_tasks

    public func applies(on day: String) -> Bool { work_date == nil || work_date == day }
}

public struct CrewTaskProduct: Decodable, Hashable {
    public let id: UUID
    public let name: String
    public let units: [String]?
}

public struct CrewTaskResponse: Decodable, Hashable {
    public let work_date: String?
    public let done: Bool
    public let value_number: Double?
    public let value_text: String?
    public let responded_at: String?
}

/// One task on one rostered day, for the Tasks tab.
public struct CrewTaskOccurrence: Decodable, Hashable, Identifiable {
    public let date: String
    public let activity: CrewOccurrenceActivity
    public let task: CrewTask
    public let response: CrewTaskResponse?
    public var id: String { "\(task.id.uuidString)|\(date)" }
}

public struct CrewOccurrenceActivity: Decodable, Hashable {
    public let id: UUID
    public let name: String
    public let color: String?
    public let is_closed: Bool
}
