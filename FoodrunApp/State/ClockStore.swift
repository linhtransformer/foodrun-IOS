import CoreNFC
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
    /// When the last clock-out happened on this device (for the "shift done" sheet).
    public var clockOutAt: Date?
    public var nfcResult: NFCResult = .none
    public var tagDetectedFlashUntil: Date?

    /// Set by ScheduleStore whenever the worker's selected shift changes.
    /// The "Klok in" button uses this to route clock_in / clock_out; a tag read
    /// sets it from the server's answer.
    public var activityId: UUID?

    /// Latest known event kind for the active (employee, activity). Cached from
    /// the last fetch or RPC response so we don't have to round-trip every tap.
    public var latestEventKind: ShiftClockKind?

    /// Set to a user-facing message when the RPC fails; the UI surfaces this
    /// as a toast and then clears it.
    public var lastError: String?

    /// A failed tag scan, shown as an alert wherever the worker is in the app
    /// (a tag can be scanned with the app closed or on any tab).
    public var tagError: String?
    /// The server's code for that failure (`no_shift_here_today`, …), so the alert can add
    /// the next shift.
    public var tagErrorCode: String?

    /// Name of the shift the last tag clocked (from the server), for the result sheet.
    public var lastTagActivityName: String?

    /// Shifts where the employer wants the tag only: no "Klok in" button
    /// (RPC get_my_clock_rules; absent = allowed).
    public private(set) var tagOnlyActivities: Set<UUID> = []

    public func allowsButton(for activityId: UUID) -> Bool {
        !tagOnlyActivities.contains(activityId)
    }

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
        clockOutAt = Date()
        nfcResult = .clockedOut
        latestEventKind = .out
    }

    public func acknowledgeNFC() {
        nfcResult = .none
    }

    // MARK: - Tag handling

    /// A tag read by the foreground NFC reader.
    public func handleTagRead(url: URL) async {
        guard let action = NFCTagAction.parse(url) else {
            tagError = FRLanguage.string("clock.tag.notFoodrun")
            FRHaptic.warning.fire()
            return
        }
        await clockWithTag(token: action.token)
    }

    /// Clock with a tag's secret. One call; the server checks the secret, finds
    /// the worker's shift at that truck or vestiging today and decides in or out
    /// (RPC clock_with_tag — see SchemaContract.md).
    public func clockWithTag(token: String) async {
        tagError = nil
        tagErrorCode = nil
        lastError = nil
        do {
            let result: ClockWithTagResult = try await SupabaseManager.shared.client
                .rpc("clock_with_tag", params: ClockWithTagParams(p_token: token))
                .execute()
                .value
            activityId = result.activity_id
            lastTagActivityName = result.activity_name
            if result.kind == "out" {
                clockedIn = false
                clockOutAt = result.event_at
                latestEventKind = .out
                nfcResult = .clockedOut
            } else {
                clockedIn = true
                clockInAt = result.event_at
                latestEventKind = .`in`
                nfcResult = .clockedIn
            }
            FRHaptic.success.fire()
        } catch {
            let raw = String(describing: error) + " " + error.localizedDescription
            tagErrorCode = Self.noShiftCodes.contains(where: raw.contains) ? "no_shift_here_today" : nil
            tagError = Self.tagMessage(for: error)
            FRHaptic.error.fire()
        }
    }

    /// "Je volgende dienst is zo 25 okt om 08:00 · Markt Haarlem."
    public static func nextShiftLine(_ shift: WorkerShift) -> String {
        let when = [PeopleFormat.day(shift.day), shift.start.map { String(format: FRLanguage.string("clock.next.at %@"), $0) }]
            .compactMap { $0 }.joined(separator: " ")
        return String(format: FRLanguage.string("clock.next %@ %@"), when, shift.activity.food_truck ?? shift.activity.name)
    }

    /// Words the server may use for "no shift here today" (the contract's, plus older spellings).
    private static let noShiftCodes = ["no_shift_here_today", "no_shift_today", "not_rostered_today"]

    /// The phone's own NFC errors, in words a crew member can act on.
    public static func readerMessage(for error: Error) -> String {
        let ns = error as NSError
        guard ns.domain == NFCReaderError.errorDomain else { return FRLanguage.string("clock.tag.failed") }
        switch NFCReaderError.Code(rawValue: ns.code) {
        case .readerTransceiveErrorTagConnectionLost, .readerTransceiveErrorRetryExceeded,
             .readerTransceiveErrorTagResponseError, .readerTransceiveErrorTagNotConnected:
            return FRLanguage.string("clock.nfc.lost")
        case .readerSessionInvalidationErrorSessionTimeout:
            return FRLanguage.string("clock.nfc.timeout")
        case .readerErrorUnsupportedFeature:
            return FRLanguage.string("clock.nfc.unsupported")
        default:
            return FRLanguage.string("clock.nfc.lost")
        }
    }

    /// Ask the server on which of these shifts the "Klok in" button may show.
    /// Best-effort: on failure the button stays (the server still refuses with
    /// `tag_required` when it isn't allowed).
    public func loadClockRules(activityIds: [UUID]) async {
        guard !activityIds.isEmpty else { return }
        guard let rules: [ClockRule] = try? await SupabaseManager.shared.client
            .rpc("get_my_clock_rules", params: ClockRulesParams(p_activity_ids: activityIds))
            .execute()
            .value else { return }
        tagOnlyActivities = Set(rules.filter { !$0.clock_without_tag }.map(\.activity_id))
    }

    private struct ClockWithTagParams: Encodable { let p_token: String }
    private struct ClockWithTagResult: Decodable {
        let kind: String          // "in" | "out"
        let activity_id: UUID
        let activity_name: String
        let event_at: Date        // server time
    }
    private struct ClockRulesParams: Encodable { let p_activity_ids: [UUID] }
    private struct ClockRule: Decodable { let activity_id: UUID; let clock_without_tag: Bool }

    /// The server raises P0001 with one of these words as the message.
    private static func tagMessage(for error: Error) -> String {
        let raw = String(describing: error) + " " + error.localizedDescription
        for (code, key) in [
            // First: it is a 42501 too, which would read as "permission denied".
            ("employee_archived", "error.employeeArchived"),
            ("invalid_tag", "clock.tag.invalid"),
            ("not_linked", "clock.tag.notLinked"),
            ("no_shift_here_today", "clock.tag.noShift"),
            ("no_shift_today", "clock.tag.noShift"),
            ("not_rostered_today", "clock.tag.noShift"),
            ("not_authenticated", "clock.tag.signIn"),
            ("permission denied", "clock.tag.signIn"),   // 42501: no session
        ] where raw.contains(code) {
            return FRLanguage.string(key)
        }
        return FRLanguage.string("clock.tag.failed")
    }

    /// Clock in or out without a tag (the "Klok in" button on today's shift) —
    /// for when there is no tag, it's broken, or the phone has no NFC. Same RPCs
    /// and same toggle rule as a tag read.
    public func toggleManually() async {
        guard let activityId else {
            lastError = FRLanguage.string("clock.error.noShift")
            FRHaptic.warning.fire()
            return
        }
        await toggle(activityId: activityId)
    }

    private func toggle(activityId: UUID) async {
        lastError = nil
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
            if (String(describing: error) + error.localizedDescription).contains("tag_required") {
                // The employer switched the button off while the app was open.
                tagOnlyActivities.insert(activityId)
                lastError = FRLanguage.string("clock.tag.required")
            } else if let archived = WorkerAPI.archivedMessage(for: error) {
                // Put "uit dienst" while the app was open.
                lastError = archived
            } else {
                lastError = friendlyError(error, direction: isCurrentlyIn ? .out : .`in`)
            }
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
        let base = FRLanguage.string(direction == .`in` ? "clock.error.in" : "clock.error.out")
        return "\(base) \(error.localizedDescription)"
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
