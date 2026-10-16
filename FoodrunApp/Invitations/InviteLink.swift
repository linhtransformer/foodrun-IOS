import Foundation
import SwiftUI

// Email invites (HQ → Stakeholders → Medewerkers → Uitnodigen). The email holds
// `https://foodrun.nl/invite/<token>` (32 URL-safe characters, 7 days, single
// use). It reaches the app as a universal link or as `foodrun://invite/<token>`
// from the web page; RootView then shows InviteView, which signs in through the
// link when needed and puts the worker on the team (SchemaContract.md →
// "Invites by email").

enum InviteLink {
    /// The invite token, or nil when the link is not a Foodrun invite.
    static func token(from url: URL) -> String? {
        let parts = url.pathComponents.filter { $0 != "/" }
        let token: String?
        switch url.scheme?.lowercased() {
        case "https":
            guard let host = url.host?.lowercased(), host == "foodrun.nl" || host.hasSuffix(".foodrun.nl"),
                  parts.count == 2, parts[0] == "invite" else { return nil }
            token = parts[1]
        case "foodrun":
            guard url.host?.lowercased() == "invite", parts.count == 1 else { return nil }
            token = parts[0]
        default:
            return nil
        }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        guard let token, token.count >= 16, token.count <= 128,
              token.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return token
    }
}

/// The invite being handled right now, set by the app's link entry points.
@MainActor
@Observable
final class PendingInvite {
    static let shared = PendingInvite()

    struct Item: Identifiable, Equatable { let token: String; var id: String { token } }

    var item: Item?
    /// Bumped after an invite is accepted, so the shell reloads the roster.
    private(set) var joinedAt: Date?

    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let token = InviteLink.token(from: url) else { return false }
        item = Item(token: token)
        return true
    }

    func markJoined() { joinedAt = Date() }
}
