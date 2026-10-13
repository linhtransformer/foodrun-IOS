import Foundation

// Pure parser for Foodrun clock-tag links.
//
// Every truck and every vestiging has an NFC tag that holds one link:
// `https://foodrun.nl/clock/<token>`. The token is a secret made in HQ (32
// URL-safe characters); the app does not interpret it — it sends it to the
// server (RPC clock_with_tag), which checks it, finds the worker's shift there
// today and clocks in or out.
//
// The same link reaches the app three ways, all through this parser:
//  * the foreground NFC reader (the worker taps the strip on a shift),
//  * a universal link when a tag is scanned with the app closed
//    (Associated Domains applinks:foodrun.nl),
//  * `foodrun://clock/<token>` from the web page for phones that opened the
//    link in a browser.
// Anything else is ignored: the reader can't stop random tags being read.

public struct NFCTagAction: Equatable {
    /// The secret from `/clock/<token>`, sent to the server as is.
    public let token: String
    /// The full link that was read.
    public let sourceURL: URL

    /// Returns nil if the link is not a Foodrun clock link.
    public static func parse(_ url: URL) -> NFCTagAction? {
        let token: String?
        switch url.scheme?.lowercased() {
        case "https":
            guard let host = url.host?.lowercased(), host == "foodrun.nl" || host.hasSuffix(".foodrun.nl") else {
                return nil
            }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 2, parts[0] == "clock" else { return nil }
            token = parts[1]
        case "foodrun":
            // foodrun://clock/<token> — "clock" is the host, the token the path.
            guard url.host?.lowercased() == "clock" else { return nil }
            let parts = url.pathComponents.filter { $0 != "/" }
            guard parts.count == 1 else { return nil }
            token = parts[0]
        default:
            return nil
        }
        guard let token, isPlausible(token) else { return nil }
        return NFCTagAction(token: token, sourceURL: url)
    }

    /// Convenience for the raw-string overload — the foreground reader hands us
    /// text payloads.
    public static func parse(_ rawURL: String) -> NFCTagAction? {
        guard let url = URL(string: rawURL) else { return nil }
        return parse(url)
    }

    /// URL-safe characters only, and long enough to be a secret rather than a
    /// guessable name. The server is what actually validates it.
    private static func isPlausible(_ token: String) -> Bool {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")
        return token.count >= 16 && token.count <= 128
            && token.unicodeScalars.allSatisfy(allowed.contains)
    }
}
