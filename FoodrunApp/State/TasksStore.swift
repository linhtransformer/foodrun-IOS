import Foundation
import SwiftUI

@MainActor
@Observable
public final class TasksStore {
    public var items: [DBTaskItem] = []
    public var gateExpanded: Bool = false

    public var completed: Int {
        items.filter { $0.completed_at != nil }.count
    }

    public var progress: Double {
        items.isEmpty ? 0 : Double(completed) / Double(items.count)
    }

    public func toggle(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[idx]
        let now: Date? = item.completed_at == nil ? Date() : nil
        item = DBTaskItem(
            id: item.id, task_id: item.task_id,
            title: item.title, note: item.note,
            requires_value: item.requires_value, requires_photo: item.requires_photo,
            value: item.value, photo_url: item.photo_url,
            completed_at: now, order: item.order
        )
        items[idx] = item
    }

    public static let preview: TasksStore = {
        let s = TasksStore()
        s.items = Fixtures.checklist
        // Mark first 3 as done so the "3/7" state matches the bundle.
        for i in 0..<3 { s.toggle(s.items[i].id) }
        return s
    }()
}
