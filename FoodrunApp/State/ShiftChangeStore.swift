import Foundation
import SwiftUI
import UserNotifications

// Shift edits made in HQ (a new time, another location, a day added to or taken
// off a festival you're on) don't produce a worker_notifications row: the
// `activity_updated` type exists but no trigger writes it (checked against the HQ
// migrations, Oct 2026). Until one does, the app spots them itself. It keeps a
// snapshot of the worker's upcoming shifts, diffs every schedule load against it
// and turns the differences into local notices (Inbox, "Changed" on the shift)
// plus a phone notification.
//
// Festivals added or removed as a whole are left out: the server already sends
// `hired` / `removed` / `activity_added` rows for those.

public struct ShiftChange: Codable, Identifiable, Hashable {
    public enum Kind: String, Codable { case time, location, added, removed }

    public let id: UUID
    public let kind: Kind
    public let activityId: UUID
    public let day: String          // "YYYY-MM-DD"
    public let name: String
    public let before: String?
    public let after: String?
    public let detectedAt: Date
    public var isRead: Bool

    public var shiftKey: String { "\(activityId.uuidString)|\(day)" }
    public var date: Date { SchemaDates.date(day) ?? detectedAt }
}

@MainActor
@Observable
public final class ShiftChangeStore {
    public private(set) var changes: [ShiftChange] = []

    private var userId: UUID?
    private let defaults = UserDefaults.standard
    private static let maxKept = 50

    public var unreadCount: Int { changes.filter { !$0.isRead }.count }

    public func isChanged(_ shift: WorkerShift) -> Bool {
        changes.contains { !$0.isRead && $0.shiftKey == shift.id && $0.kind != .removed }
    }

    // MARK: - Tracking

    /// Compare the freshly loaded shifts with the last snapshot, record what
    /// changed and notify. The first run for a user only stores the snapshot.
    @discardableResult
    public func track(_ shifts: [WorkerShift], today: String, userId: UUID) -> [ShiftChange] {
        // Re-read every time: the background refresh may have recorded changes.
        restore(for: userId)

        let current = Self.snapshot(of: shifts.filter { $0.day >= today })
        guard let previous = defaults.dictionary(forKey: snapshotKey(userId)) as? [String: [String: String]] else {
            defaults.set(current, forKey: snapshotKey(userId))
            return []
        }
        // Days that have passed since the last load aren't edits.
        let old = previous.filter { Self.day(of: $0.key) >= today }

        let found = Self.diff(old: old, new: current)
        defaults.set(current, forKey: snapshotKey(userId))
        guard !found.isEmpty else { return [] }

        changes = Array((found + changes).prefix(Self.maxKept))
        save()
        Self.postNotification(for: found)
        return found
    }

    public func markRead(_ id: UUID) {
        guard let i = changes.firstIndex(where: { $0.id == id }), !changes[i].isRead else { return }
        changes[i].isRead = true
        save()
    }

    public func markRead(activityId: UUID, day: String) {
        var touched = false
        for i in changes.indices where changes[i].activityId == activityId && changes[i].day == day && !changes[i].isRead {
            changes[i].isRead = true
            touched = true
        }
        if touched { save() }
    }

    // MARK: - Text

    public static func title(_ change: ShiftChange) -> String {
        switch change.kind {
        case .time: return FRLanguage.string("shiftChange.title.time")
        case .location: return FRLanguage.string("shiftChange.title.location")
        case .added: return FRLanguage.string("shiftChange.title.added")
        case .removed: return FRLanguage.string("shiftChange.title.removed")
        }
    }

    public static func body(_ change: ShiftChange) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        let lead = "\(change.name) · \(f.string(from: change.date))"
        switch change.kind {
        case .time: return "\(lead) · \(time(change.before)) → \(time(change.after))"
        case .added: return "\(lead) · \(time(change.after))"
        case .location: return change.after.map { "\(lead) · \($0)" } ?? lead
        case .removed: return lead
        }
    }

    private static func time(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return FRLanguage.string("shift.timeTBD") }
        return value
    }

    // MARK: - Phone notification

    public static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    private static func postNotification(for found: [ShiftChange]) {
        let content = UNMutableNotificationContent()
        if found.count == 1, let change = found.first {
            content.title = title(change)
            content.body = body(change)
        } else {
            content.title = FRLanguage.string("shiftChange.title.many")
            content.body = found.prefix(3).map(body).joined(separator: "\n")
        }
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Diff

    /// shiftKey → fields we compare. Plain strings so the snapshot stays a property list.
    private static func snapshot(of shifts: [WorkerShift]) -> [String: [String: String]] {
        var out: [String: [String: String]] = [:]
        for s in shifts {
            out[s.id] = [
                "name": s.activity.name,
                // Raw times, not timeLabel: that one is translated.
                "time": [s.start, s.end].compactMap { $0.map { String($0.prefix(5)) } }.joined(separator: " – "),
                "location": s.activity.location ?? "",
            ]
        }
        return out
    }

    private static func diff(old: [String: [String: String]], new: [String: [String: String]]) -> [ShiftChange] {
        let oldActivities = Set(old.keys.map(activity(of:)))
        let newActivities = Set(new.keys.map(activity(of:)))
        let now = Date()
        var found: [ShiftChange] = []

        func change(_ kind: ShiftChange.Kind, _ key: String, _ fields: [String: String], before: String?, after: String?) {
            guard let activityId = UUID(uuidString: activity(of: key)) else { return }
            found.append(ShiftChange(
                id: UUID(), kind: kind, activityId: activityId, day: day(of: key),
                name: fields["name"] ?? "", before: before, after: after,
                detectedAt: now, isRead: false
            ))
        }

        for (key, n) in new {
            if let o = old[key] {
                if o["time"] != n["time"] {
                    change(.time, key, n, before: o["time"], after: n["time"])
                }
                if o["location"] != n["location"], let loc = n["location"], !loc.isEmpty {
                    change(.location, key, n, before: o["location"], after: loc)
                }
            } else if oldActivities.contains(activity(of: key)) {
                change(.added, key, n, before: nil, after: n["time"])
            }
        }
        for (key, o) in old where new[key] == nil && newActivities.contains(activity(of: key)) {
            change(.removed, key, o, before: o["time"], after: nil)
        }
        return found.sorted { $0.day < $1.day }
    }

    private static func activity(of key: String) -> String { String(key.split(separator: "|").first ?? "") }
    private static func day(of key: String) -> String { String(key.split(separator: "|").last ?? "") }

    // MARK: - Persistence (per auth user, on this device)

    private func snapshotKey(_ id: UUID) -> String { "shiftSnapshot-\(id.uuidString)" }
    private func changesKey(_ id: UUID) -> String { "shiftChanges-\(id.uuidString)" }

    private func restore(for id: UUID) {
        userId = id
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        if let data = defaults.data(forKey: changesKey(id)),
           let saved = try? JSONDecoder().decode([ShiftChange].self, from: data) {
            changes = saved.filter { $0.detectedAt > cutoff }
        } else {
            changes = []
        }
    }

    private func save() {
        guard let userId, let data = try? JSONEncoder().encode(changes) else { return }
        defaults.set(data, forKey: changesKey(userId))
    }
}
