import Foundation
import SwiftUI
import Supabase

// Clock-in / clock-out state. Drives the hero timer, checklist gate, and NFC
// result sheet. Talks to the same Supabase RPCs the web PWA hits
// (`clock_in` / `clock_out` — see SchemaContract.md and useShiftClock.ts:111-151).
//
// The tap-to-toggle contract: one URL per truck, always. The store peeks at
// the latest shift_clock_events row and picks the opposite RPC. That way the
// tag payload never changes and neither operators nor workers have to
// remember direction.

@MainActor
@Observable
public final class ClockStore {
    public enum NFCResult: Equatable { case none, clockedIn, clockedOut }

    public var clockedIn: Bool = false
    public var clockInAt: Date?
    public var nfcResult: NFCResult = .none
    public var tagDetectedFlashUntil: Date?

    /// Set by ScheduleStore whenever the worker's selected shift changes.
    /// handleTagRead uses this to route clock_in/clock_out to the right activity.
    public var activityId: UUID?

    /// Latest known event kind for the active (employee, activity). Cached from
    /// the last fetch or RPC response so we don't have to round-trip every tap.
    public var latestEventKind: ShiftClockKind?

    /// Set to a user-facing message when the RPC fails; the UI surfaces this
    /// as a toast and then clears it.
    public var lastError: String?

    /// How long the current clock-in has been running.
    public var elapsed: TimeInterval {
        guard clockedIn, let start = clockInAt else { return 0 }
        return Date().timeIntervalSince(start)
    }

    public func recordClockIn(at date: Date = Date()) {
        clockedIn = true
        clockInAt = date
        nfcResult = .clockedIn
        latestEventKind = .`in`
    }

    public func recordClockOut() {
        clockedIn = false
        nfcResult = .clockedOut
        latestEventKind = .out
    }

    public func acknowledgeNFC() {
        nfcResult = .none
    }

    // MARK: - Tag handling

    /// Called by the NFC listening surfaces after a foreground read.
    /// Contract:
    ///   1. Validate the URL is one of ours (NFCTagAction.parse).
    ///   2. Decide direction from `latestEventKind`.
    ///   3. Call the RPC. Server stamps event_at + updates the audit log.
    ///   4. Mutate local state so the hero timer + result sheet update in one tick.
    ///
    /// The employee_id lookup is the caller's responsibility (it comes from
    /// the signed-in `employees` row) so the store stays orthogonal to auth.
    public func handleTagRead(url: URL, employeeId: UUID) async {
        guard let action = NFCTagAction.parse(url) else {
            lastError = "That tag isn't a Foodrun clock tag."
            FRHaptic.warning.fire()
            return
        }
        guard let activityId else {
            lastError = "You don't have a shift assigned right now."
            FRHaptic.warning.fire()
            return
        }
        _ = action.truckSlug   // kept in scope for future audit-log wiring

        // Direction: `.in` and `.break_end` mean currently on the clock.
        let isCurrentlyIn = latestEventKind == .`in` || latestEventKind == .break_end
        let targetRPC = isCurrentlyIn ? "clock_out" : "clock_in"

        do {
            _ = try await SupabaseManager.shared.client.rpc(
                targetRPC,
                params: ClockRPCParams(p_activity_id: activityId, p_lat: nil, p_lng: nil, p_accuracy_m: nil)
            ).execute()
            if isCurrentlyIn {
                recordClockOut()
            } else {
                recordClockIn(at: Date())
            }
            FRHaptic.success.fire()
        } catch {
            lastError = friendlyError(error, direction: isCurrentlyIn ? .out : .`in`)
            FRHaptic.error.fire()
        }
    }

    /// Ambient status refresh — call on `onAppear` of Shifts to pick up any
    /// events written by another device (e.g. the operator clocked the worker
    /// out from the dashboard). Best-effort; failures update `lastError`
    /// silently — the UI just doesn't refresh.
    public func refreshLatestEvent(employeeId: UUID) async {
        guard let activityId else { return }
        do {
            let since = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-24 * 3600))
            let events: [DBShiftClockEvent] = try await SupabaseManager.shared.client
                .from("shift_clock_events")
                .select("*")
                .eq("employee_id", value: employeeId.uuidString)
                .eq("activity_id", value: activityId.uuidString)
                .gte("event_at", value: since)
                .order("event_at", ascending: false)
                .limit(1)
                .execute()
                .value
            let latest = events.first
            latestEventKind = latest?.kind
            switch latest?.kind {
            case .`in`, .break_end:
                clockedIn = true
                clockInAt = latest?.event_at
            case .out, .break_start, nil:
                clockedIn = false
                clockInAt = nil
            }
        } catch {
            // Non-fatal — leave existing local state alone.
        }
    }

    private struct ClockRPCParams: Encodable {
        let p_activity_id: UUID
        let p_lat: Double?
        let p_lng: Double?
        let p_accuracy_m: Double?
    }

    private enum Direction { case `in`, out }

    private func friendlyError(_ error: Error, direction: Direction) -> String {
        let base = direction == .`in` ? "Couldn't clock in" : "Couldn't clock out"
        return "\(base): \(error.localizedDescription)"
    }

    // MARK: - Preview

    public static let preview: ClockStore = {
        let s = ClockStore()
        return s
    }()

    public static let previewClockedIn: ClockStore = {
        let s = ClockStore()
        s.clockedIn = true
        s.clockInAt = Fixtures.calendar.date(byAdding: .minute, value: -134, to: Date()) ?? Date()
        s.latestEventKind = .`in`
        return s
    }()
}
