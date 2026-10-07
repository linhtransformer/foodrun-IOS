import Foundation
import SwiftUI

// Tasks tab: every task the operator gave this crew member, one entry per
// rostered day, today through the next week (get_my_crew_tasks). Replaces the
// local sample checklist (TasksStore) for real users.

@MainActor
@Observable
public final class CrewTasksStore {
    public var occurrences: [CrewTaskOccurrence] = []
    public var isLoading = false
    public var hasLoaded = false
    public var lastError: String?
    public var saving: Set<String> = []

    public init() {}

    public func load(today: Date = Date()) async {
        isLoading = true
        defer { isLoading = false; hasLoaded = true }
        let cal = Calendar(identifier: .gregorian)
        let from = SchemaDates.string(today)
        let to = SchemaDates.string(cal.date(byAdding: .day, value: 7, to: today) ?? today)
        do {
            occurrences = try await CrewAPI.fetchTasks(from: from, to: to)
            lastError = nil
        } catch {
            lastError = CrewAPI.message(for: error)
        }
    }

    /// Occurrences grouped per day, in date order.
    public var days: [CrewTaskDay] {
        let grouped = Dictionary(grouping: occurrences, by: \.date)
        return grouped.keys.sorted().map { CrewTaskDay(day: $0, items: grouped[$0] ?? []) }
    }

    public func openCount(on day: String) -> Int {
        occurrences.filter { $0.date == day && !($0.response?.done ?? false) }.count
    }

    @discardableResult
    public func answer(_ occurrence: CrewTaskOccurrence, done: Bool, number: Double? = nil, text: String? = nil) async -> Bool {
        saving.insert(occurrence.id)
        defer { saving.remove(occurrence.id) }
        do {
            try await CrewAPI.answer(taskId: occurrence.task.id, day: occurrence.date,
                                     done: done, number: number, text: text)
            await load()
            return true
        } catch {
            lastError = CrewAPI.message(for: error)
            return false
        }
    }
}

public struct CrewTaskDay: Identifiable {
    public let day: String
    public let items: [CrewTaskOccurrence]
    public var id: String { day }
}
