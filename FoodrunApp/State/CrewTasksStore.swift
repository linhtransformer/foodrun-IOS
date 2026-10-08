import Foundation
import SwiftUI

// Tasks tab: every task the operator gave this crew member, one entry per
// rostered day, today through the next week (get_my_crew_tasks). Replaces the
// local sample checklist (TasksStore) for real users.

@MainActor
@Observable
public final class CrewTasksStore {
    public var occurrences: [CrewTaskOccurrence] = []
    /// Prep checklists and stock counts as tasks (get_my_crew_lists).
    public var lists: [CrewListEntry] = []
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
        // Separate call: an older server without it still shows the tasks.
        lists = (try? await CrewAPI.fetchLists(from: from, to: to)) ?? []
    }

    /// Tasks and lists grouped per day, in date order.
    public var days: [CrewTaskDay] {
        let tasksByDay = Dictionary(grouping: occurrences, by: \.date)
        let listsByDay = Dictionary(grouping: lists, by: \.date)
        let keys = Set(tasksByDay.keys).union(listsByDay.keys).sorted()
        return keys.map { CrewTaskDay(day: $0, lists: listsByDay[$0] ?? [], items: tasksByDay[$0] ?? []) }
    }

    public func openCount(on day: String) -> Int {
        occurrences.filter { $0.date == day && !($0.response?.done ?? false) }.count
            + lists.filter { $0.date == day && !$0.isFinished }.count
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

extension CrewTasksStore {
    /// Photo task from the Tasks tab. The employee id is this person's row at
    /// the event's operator (ScheduleStore.employee(for:)).
    @discardableResult
    public func answerPhoto(_ occurrence: CrewTaskOccurrence, employeeId: UUID, jpeg: Data) async -> Bool {
        saving.insert(occurrence.id)
        defer { saving.remove(occurrence.id) }
        do {
            let path = try await CrewAPI.uploadTaskPhoto(activityId: occurrence.activity.id, taskId: occurrence.task.id,
                                                         employeeId: employeeId, jpeg: jpeg)
            try await CrewAPI.answer(taskId: occurrence.task.id, day: occurrence.date, done: true, photoPath: path)
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
    public let lists: [CrewListEntry]
    public let items: [CrewTaskOccurrence]
    public var id: String { day }
}
