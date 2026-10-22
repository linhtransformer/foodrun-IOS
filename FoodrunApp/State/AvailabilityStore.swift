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

    /// Window a day starts with, for both "available" and "not available":
    /// 07:00 – 23:00, a full truck day. The worker narrows it with the slider.
    public static let defaultWindow: ClosedRange<Int> = 7...23

    public var state: [String: State] = [:]              // "YYYY-MM-DD" → state
    public var window: [String: ClosedRange<Int>] = [:]  // hour range 0…24
    public var reason: [String: String] = [:]
    /// Wanted shifts per week (Monday "YYYY-MM-DD" → 0…7), employee_week_preferences.
    private var wantedByWeek: [String: Int] = [:]
    /// Weeks whose number changed and still has to be saved.
    private var wantedDirty: Set<String> = []
    /// The week on screen (set by loadWanted / setWanted).
    public private(set) var currentWeek = ""
    /// Wanted shifts for the week on screen; 3 until the worker says otherwise.
    public var wantShifts: Int { wantedByWeek[currentWeek] ?? 3 }
    public var standardShifts: Int = 4                    // local preference
    /// The employers' rules (closed days, deadline, reason) — get_my_availability_rules.
    public var rules: [MyAvailabilityRules] = []
    /// Days edited since the last save.
    public private(set) var dirty: Set<String> = []
    public var isSaving = false
    public var lastError: String?

    public func stateFor(_ date: Date) -> State {
        state[ScheduleStore.iso(date)] ?? .unset
    }

    public func windowFor(_ date: Date) -> ClosedRange<Int> {
        window[ScheduleStore.iso(date)] ?? Self.defaultWindow
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

    // MARK: - Rules and wanted shifts

    /// "YYYY-MM-DD" of the Monday of `date`'s week (Amsterdam).
    public static func monday(of date: Date) -> String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "Europe/Amsterdam") ?? .current
        let start = cal.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return SchemaDates.string(start)
    }

    /// The employer that closed this day for availability, if one did.
    public func closedBy(_ date: Date) -> String? {
        let key = ScheduleStore.iso(date)
        return rules.first { ($0.closed_days ?? []).contains(key) }?.organization_name
    }

    /// The earliest moment an employer stops taking availability for `date`'s week.
    public func closesAt(weekOf date: Date) -> Date? {
        guard let monday = SchemaDates.date(Self.monday(of: date)) else { return nil }
        return rules.compactMap { $0.closesAt(weekStarting: monday) }.min()
    }

    public var reasonRequired: Bool { rules.contains { $0.reason_required } }

    public func setWanted(_ count: Int, weekOf date: Date) {
        currentWeek = Self.monday(of: date)
        wantedByWeek[currentWeek] = max(0, min(7, count))
        wantedDirty.insert(currentWeek)
    }

    public func loadWanted(employeeIds: [UUID], weekOf date: Date) async {
        let week = Self.monday(of: date)
        currentWeek = week
        // An unsaved change for this week wins over what the server has.
        guard !wantedDirty.contains(week) else { return }
        if let n = try? await PeopleAPI.wantedShifts(employeeIds: employeeIds, weekStart: week) {
            wantedByWeek[week] = n
        }
    }

    // MARK: - Live data

    public func load(employeeIds: [UUID]) async {
        if let r = try? await PeopleAPI.availabilityRules() { rules = r }
        do {
            let rows = try await WorkerAPI.fetchAvailability(employeeIds: employeeIds)
            // Multi-operator rows carry the same statement — first one per date wins.
            for row in rows where state[row.date] == nil || !dirty.contains(row.date) {
                // "maybe" (partly unavailable, set on the web) counts as available here, with its window.
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
        guard !dirty.isEmpty || !wantedDirty.isEmpty else { return true }
        isSaving = true
        defer { isSaving = false }
        do {
            if !employeeIds.isEmpty {
                for week in wantedDirty.sorted() {
                    try await PeopleAPI.setWantedShifts(employeeIds: employeeIds, weekStart: week, count: wantedByWeek[week] ?? 3)
                    wantedDirty.remove(week)
                }
            }
            for day in dirty.sorted() {
                let s = state[day] ?? .unset
                let w = window[day] ?? Self.defaultWindow
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
            lastError = WorkerAPI.archivedMessage(for: error) ?? error.localizedDescription
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
