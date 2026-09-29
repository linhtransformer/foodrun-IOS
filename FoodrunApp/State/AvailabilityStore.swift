import Foundation
import SwiftUI

// Availability mode state — per-day window (whole hours), available/unavailable,
// optional reason. Persisted to employee_availability exactly like the web's
// useMyAvailability().setStatus: one row per employee × date, fanned out to
// every linked employee row, window stored as a minute-range slot. Operators
// see it on HQ's scheduling board when they plan the roster.

@MainActor
@Observable
public final class AvailabilityStore {
    public enum State: String, Codable { case available, unavailable, unset }

    public var state: [String: State] = [:]              // "YYYY-MM-DD" → state
    public var window: [String: ClosedRange<Int>] = [:]  // hour range 0…24
    public var reason: [String: String] = [:]
    public var wantShifts: Int = 3                        // 0…7 (local preference)
    public var standardShifts: Int = 4
    /// Days edited since the last save.
    public private(set) var dirty: Set<String> = []
    public var isSaving = false
    public var lastError: String?

    public func stateFor(_ date: Date) -> State {
        state[ScheduleStore.iso(date)] ?? .unset
    }

    public func windowFor(_ date: Date) -> ClosedRange<Int> {
        window[ScheduleStore.iso(date)] ?? (7...15)
    }

    public func reasonFor(_ date: Date) -> String {
        reason[ScheduleStore.iso(date)] ?? ""
    }

    public func setState(_ new: State, for date: Date) {
        let key = ScheduleStore.iso(date)
        state[key] = new
        dirty.insert(key)
    }

    public func setWindow(_ new: ClosedRange<Int>, for date: Date) {
        // Enforce ≥ 1h and 0…24 clamp.
        let low = max(0, min(new.lowerBound, 23))
        let high = min(24, max(new.upperBound, low + 1))
        let key = ScheduleStore.iso(date)
        window[key] = low...high
        dirty.insert(key)
    }

    public func setReason(_ text: String, for date: Date) {
        let key = ScheduleStore.iso(date)
        reason[key] = text
        dirty.insert(key)
    }

    // MARK: - Live data

    public func load(employeeIds: [UUID]) async {
        do {
            let rows = try await WorkerAPI.fetchAvailability(employeeIds: employeeIds)
            // Multi-operator rows carry the same statement — first one per date wins.
            for row in rows where state[row.date] == nil || !dirty.contains(row.date) {
                state[row.date] = row.status == "unavailable" ? .unavailable : .available
                reason[row.date] = row.note ?? ""
                if let slot = row.slots?.first {
                    window[row.date] = max(0, slot.start / 60)...min(24, max(slot.start / 60 + 1, Int((Double(slot.end) / 60).rounded(.up))))
                }
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Write every edited day. A day marked "unset" clears the row.
    @discardableResult
    public func saveDirty(employeeIds: [UUID]) async -> Bool {
        guard !dirty.isEmpty else { return true }
        isSaving = true
        defer { isSaving = false }
        do {
            for day in dirty.sorted() {
                let s = state[day] ?? .unset
                let w = window[day] ?? (7...15)
                let status: String? = s == .unset ? nil : s.rawValue
                let slots = status.map { [DBAvailabilitySlot(start: w.lowerBound * 60, end: w.upperBound * 60, status: $0)] }
                let note = (reason[day] ?? "").trimmingCharacters(in: .whitespaces)
                try await WorkerAPI.setAvailability(
                    employeeIds: employeeIds,
                    date: day,
                    status: status,
                    note: note.isEmpty ? nil : note,
                    slots: slots
                )
            }
            dirty.removeAll()
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    public static let preview: AvailabilityStore = {
        let s = AvailabilityStore()
        s.setState(.available, for: Fixtures.today)
        s.setWindow(7...15, for: Fixtures.today)
        return s
    }()
}
