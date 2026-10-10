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

/// The event briefing — what the script portal shows on its Draaiboek and Setup
/// tabs, minus what the operator hid (HQ migration 20261008210000). Everything
/// but headings/notes is optional so an older server still decodes.
public struct CrewBriefing: Decodable, Hashable {
    public let headings: [CrewHeading]
    public let notes: [CrewNote]                 // my day per date: times + operator note
    public let title: String?
    public let updated_at: String?               // script (or activity) last edit, shown as "Briefing updated …"
    public let date: CrewBriefingDate?
    public let hours: CrewBriefingHours?
    public let locations: [CrewLocation]?
    public let event_notes: String?
    public let food_truck: String?
    public let overnight_stay: String?
    public let daily_comments: [CrewDailyComment]?
    public let links: [CrewLink]?
    public let files: [CrewFile]?                // event files (activity-files)
    public let my_tickets: [CrewTicket]?
    public let unnamed_tickets: [CrewFile]?
    public let my_files: [CrewFile]?             // my employee files
    public let team: [CrewTeamDay]?
    public let setup: CrewSetupBlock?
    public let teardown: CrewSetupBlock?
    public let electricity: CrewPower?
}

/// The electricity plan (script portal "Stroom"): lines → outlets → plugged-in
/// products. Load is computed in the app like HQ's StroomplanPreview.
public struct CrewPower: Decodable, Hashable {
    public let comment: String?
    public let v230: Int?
    public let a16: Int?
    public let a32: Int?
    public let lines: [CrewPowerLine]
}

public struct CrewPowerLine: Decodable, Hashable {
    public let type: String          // 230v | 16a | 32a
    public let outlets: [CrewPowerOutlet]
}

public struct CrewPowerOutlet: Decodable, Hashable {
    public let items: [CrewPowerItem]
}

public struct CrewPowerItem: Decodable, Hashable {
    public let name: String
    public let quantity: Double
    public let watts: Double         // per unit
    public let split_id: String?     // one appliance spread over several outlets
}

public struct CrewBriefingDate: Decodable, Hashable {
    public let start: String?
    public let end: String?
    public let comment: String?
}

public struct CrewBriefingHours: Decodable, Hashable {
    public let days: [CrewHoursDay]
    public let start: String?
    public let end: String?
    public let comment: String?
}

public struct CrewHoursDay: Decodable, Hashable {
    public let date: String
    public let start: String?
    public let end: String?
}

public struct CrewLocation: Decodable, Hashable {
    public let name: String?
    public let address: String?
    public let notes: String?
    public let image: String?
    public let lat: Double?
    public let lng: Double?
    public let added_by: String?     // crew member who pinned it from the app
    public let pin_id: String?
    public let mine: Bool?           // I pinned it → I may remove it
}

public struct CrewDailyComment: Decodable, Hashable {
    public let date: String
    public let text: String
}

public struct CrewLink: Decodable, Hashable, Identifiable {
    public let title: String
    public let url: String
    public var id: String { url + "|" + title }
}

/// A stored file: private buckets (activity-files, employee-files) open via a
/// signed URL, public ones (heading photos/PDFs, setup photos) directly.
public struct CrewFile: Decodable, Hashable, Identifiable {
    public let bucket: String
    public let path: String
    public let name: String
    public var id: String { bucket + "/" + path }
}

/// One of my tickets: for one day, or for every day of the event.
public struct CrewTicket: Decodable, Hashable, Identifiable {
    public let bucket: String
    public let path: String
    public let name: String
    public let date: String?
    public let all_days: Bool?
    public var id: String { bucket + "/" + path + "|" + (date ?? "") }
    public var file: CrewFile { CrewFile(bucket: bucket, path: path, name: name) }
}

public struct CrewTeamDay: Decodable, Hashable {
    public let date: String
    public let names: [String]
}

/// Build-up or teardown (activities.setup_* / teardown_*).
public struct CrewSetupBlock: Decodable, Hashable {
    public let note: String?
    public let date: String?
    public let start: String?
    public let end: String?
    public let comments: String?
    public let images: [CrewFile]?
}

public struct CrewHeading: Decodable, Hashable, Identifiable {
    public let id: UUID
    public let name: String
    public let content: String?
    public let icon: String?         // card icon key chosen in the script editor
    public let images: [CrewFile]?
    public let attachments: [CrewFile]?
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
    public let image: String?            // public photo URL (HQ → Gerechten)
    public let serving_size: Double?
    public let estimated_quantity: Double?
    public let ingredients: [CrewIngredient]
    public let price: Double?            // per-event price (activities.dishes)
    public let coin_price: Double?       // price in coins, when the event uses coins
    public let allergens: [String]?      // keys: Gluten, Dairy, Eggs, …
    public let may_contain: String?

    public var imageURL: URL? { image.flatMap(URL.init(string:)) }
}

/// Per-serving amount in the unit the operator chose for the dish.
public struct CrewIngredient: Decodable, Hashable, Identifiable {
    public let product_id: UUID
    public let name: String
    public let quantity: Double
    public let unit: String?
    public var id: UUID { product_id }
}

/// Prep checklist — the same list and ticks as the prep portal. Editable from
/// the app (set_my_prep_item); the server merges per item, so the app and the
/// portal can tick at the same time.
public struct CrewPrep: Decodable, Hashable {
    public let updated_at: String?
    public let editable: Bool?
    public let items: [CrewPrepItem]
}

public struct CrewPrepItem: Decodable, Hashable, Identifiable {
    public let key: String          // ing-/equip-/addon-/trailer-<id>, same keys as the portal
    public let section: String      // ingredients | equipment | rentals | trailers | addons
    public let product_id: UUID     // product id (vehicle id for trailers)
    public let name: String
    public let quantity: Double          // needed, in units[quantity_level]
    public let unit: String?
    public let quantity_level: Int?
    public let units: [String]?          // unit chain, outermost first (["doos", "pak", "ml"])
    public let packed: Double?           // amount actually packed, in units[packed_level]
    public let packed_level: Int?
    public let checked: Bool
    public let comment: String?          // crew/packer note on the row
    public let instruction: String?      // operator instruction (HQ → Crew-app → Prep-checklist)
    public var id: String { key }

    /// Units an amount can be entered in (falls back to the row's own unit).
    public var unitNames: [String] {
        if let units, !units.isEmpty { return units }
        return unit.map { [$0] } ?? []
    }
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
    case check, count, number, text, photo, other

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = CrewTaskKind(rawValue: raw) ?? .other
    }

    /// Kinds answered with a value rather than a tick.
    public var asksValue: Bool { self == .count || self == .number || self == .text }
}

public struct CrewTask: Decodable, Hashable, Identifiable {
    public let id: UUID
    public let activity_id: UUID?        // nil for a week goal
    public let work_date: String?        // nil = every day of the event
    public let week_start: String?       // week goal: the Monday of its week
    public let checklist_id: UUID?       // rows of one applied checklist share this
    public let checklist_title: String?
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
    public let photo_path: String?       // crew-task-photos/<activity>/<task>/<employee>/<file>
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

/// A goal for the week, not tied to a shift (get_my_week_goals). Answered once
/// per person with work_date = week_start.
public struct CrewWeekGoal: Decodable, Hashable, Identifiable {
    public let week_start: String
    public let task: CrewTask
    public let response: CrewTaskResponse?
    public var id: String { task.id.uuidString }
}

/// Tasks that came from one checklist (HQ → Taken → Bibliotheek), or the
/// loose tasks (title nil). Built in the app from CrewTask.checklist_id.
public struct CrewTaskGroup<Item>: Identifiable {
    public let id: String
    public let title: String?
    public let items: [Item]

    /// Loose tasks first, then one group per checklist in first-seen order.
    public static func build(_ items: [Item], task: (Item) -> CrewTask) -> [CrewTaskGroup<Item>] {
        var order: [String] = []
        var byKey: [String: [Item]] = [:]
        var titles: [String: String] = [:]
        for item in items {
            let t = task(item)
            let key = t.checklist_id?.uuidString ?? ""
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(item)
            if let title = t.checklist_title { titles[key] = title }
        }
        let sorted = order.filter { $0.isEmpty } + order.filter { !$0.isEmpty }
        return sorted.map { CrewTaskGroup(id: $0.isEmpty ? "loose" : $0, title: $0.isEmpty ? nil : titles[$0], items: byKey[$0] ?? []) }
    }
}

/// A list-type task for the Tasks tab (get_my_crew_lists): the prep checklist
/// or the stock count of one event on one day, with progress.
public struct CrewListEntry: Decodable, Hashable, Identifiable {
    public let date: String
    public let kind: String          // prep | stock
    public let activity: CrewOccurrenceActivity
    public let done: Int
    public let total: Int
    public var id: String { "\(kind)|\(activity.id.uuidString)|\(date)" }
    public var isFinished: Bool { total > 0 && done >= total }
}

public struct CrewOccurrenceActivity: Decodable, Hashable {
    public let id: UUID
    public let name: String
    public let color: String?
    public let is_closed: Bool
}
