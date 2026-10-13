import Foundation
import SwiftUI

// A clock tag scanned while the app was closed, in the background, or not signed
// in yet. The app entry point (universal link / foodrun://clock/…) drops the
// token here; AppShell picks it up as soon as a signed-in shell is on screen and
// hands it to ClockStore. Kept only in memory and only for a short while, so an
// old scan never clocks someone hours later.

@MainActor
@Observable
final class ScannedClockTag {
    static let shared = ScannedClockTag()

    private(set) var token: String?
    private var receivedAt: Date?

    /// Returns true when the link was a Foodrun clock link (and was taken).
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let action = NFCTagAction.parse(url) else { return false }
        token = action.token
        receivedAt = Date()
        return true
    }

    /// The waiting token, once; nil when there is none or it is older than
    /// ten minutes (e.g. the worker scanned, then took a while to sign in).
    func take() -> String? {
        defer { token = nil; receivedAt = nil }
        guard let token, let receivedAt, Date().timeIntervalSince(receivedAt) < 600 else { return nil }
        return token
    }
}
