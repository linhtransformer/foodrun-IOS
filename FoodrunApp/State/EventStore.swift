import Foundation
import SwiftUI

// One event as this crew member may see it: the sections the operator turned
// on (briefing, dishes, prep, stock) plus their assigned tasks. Loaded per
// event screen from get_my_event; answers/counts reload it so the screen
// always shows what the server stored.

@MainActor
@Observable
public final class EventStore {
    public let activityId: UUID
    public var event: CrewEvent?
    public var isLoading = false
    public var lastError: String?
    /// Task/product ids with a save in flight (spinner + no double taps).
    public var saving: Set<UUID> = []

    public init(activityId: UUID) {
        self.activityId = activityId
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            event = try await CrewAPI.fetchEvent(activityId: activityId)
            lastError = nil
        } catch {
            lastError = CrewAPI.message(for: error)
        }
    }

    // MARK: - Tasks

    public func tasks(on day: String) -> [CrewTask] {
        (event?.tasks ?? []).filter { $0.applies(on: day) }
    }

    public func response(for task: CrewTask, on day: String) -> CrewTaskResponse? {
        task.responses?.first { $0.work_date == day }
    }

    @discardableResult
    public func answer(_ task: CrewTask, on day: String, done: Bool, number: Double? = nil, text: String? = nil) async -> Bool {
        saving.insert(task.id)
        defer { saving.remove(task.id) }
        do {
            try await CrewAPI.answer(taskId: task.id, day: day, done: done, number: number, text: text)
            await load()
            return true
        } catch {
            lastError = CrewAPI.message(for: error)
            return false
        }
    }

    /// Photo task: upload the picture, then mark the task done with its path.
    @discardableResult
    public func answerPhoto(_ task: CrewTask, on day: String, jpeg: Data) async -> Bool {
        guard let employeeId = event?.employee_id else { return false }
        saving.insert(task.id)
        defer { saving.remove(task.id) }
        do {
            let path = try await CrewAPI.uploadTaskPhoto(activityId: activityId, taskId: task.id,
                                                         employeeId: employeeId, jpeg: jpeg)
            try await CrewAPI.answer(taskId: task.id, day: day, done: true, photoPath: path)
            await load()
            return true
        } catch {
            lastError = CrewAPI.message(for: error)
            return false
        }
    }

    // MARK: - Prep checklist (shared with the prep portal)

    /// Prep keys with a save in flight.
    public var savingPrep: Set<String> = []

    @discardableResult
    public func togglePrep(_ item: CrewPrepItem) async -> Bool {
        await setPrep(item, checked: !item.checked, comment: nil)
    }

    /// Note on an item ("" removes it).
    @discardableResult
    public func notePrep(_ item: CrewPrepItem, comment: String) async -> Bool {
        await setPrep(item, checked: nil, comment: comment)
    }

    private func setPrep(_ item: CrewPrepItem, checked: Bool?, comment: String?) async -> Bool {
        savingPrep.insert(item.key)
        defer { savingPrep.remove(item.key) }
        do {
            try await CrewAPI.setPrepItem(activityId: activityId, key: item.key, checked: checked, comment: comment)
            await load()
            return true
        } catch {
            lastError = CrewAPI.message(for: error)
            return false
        }
    }

    // MARK: - Stock counts

    public func myCount(productId: UUID, on day: String) -> CrewStockCount? {
        event?.stock?.my_counts.last { $0.product_id == productId && $0.count_date == day }
    }

    @discardableResult
    public func count(productId: UUID, on day: String, quantity: Double?, unitLevel: Int) async -> Bool {
        saving.insert(productId)
        defer { saving.remove(productId) }
        do {
            try await CrewAPI.count(activityId: activityId, day: day, productId: productId,
                                    quantity: quantity, unitLevel: unitLevel)
            await load()
            return true
        } catch {
            lastError = CrewAPI.message(for: error)
            return false
        }
    }
}
