import Foundation
import SwiftUI

// worker_notifications for the signed-in worker — the same rows /me/inbox shows.
// Written server-side (e.g. notify_worker_on_hours_decision() when the operator
// approves or rejects hours in HQ → Stakeholders → Uren).

@MainActor
@Observable
public final class InboxStore {
    public var items: [DBWorkerNotification] = []
    public var lastError: String?

    public var unreadCount: Int {
        items.filter { !$0.is_read }.count
    }

    public func load() async {
        do {
            items = try await WorkerAPI.fetchInbox()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func markRead(_ id: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == id }), !items[idx].is_read else { return }
        let old = items[idx]
        items[idx] = DBWorkerNotification(
            id: old.id, user_id: old.user_id, activity_id: old.activity_id, type: old.type,
            title: old.title, body: old.body, url: old.url, is_read: true,
            operator_name: old.operator_name, created_at: old.created_at
        )
        Task {
            do { try await WorkerAPI.markRead(id) } catch { lastError = error.localizedDescription }
        }
    }

    public static let preview: InboxStore = {
        let s = InboxStore()
        s.items = Fixtures.inbox
        return s
    }()
}
