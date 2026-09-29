import Foundation

// Pure parser for Foodrun clock-in tag URLs.
//
// Every truck's NFC tag holds one URL: `https://foodrun.nl/clock/<truck_slug>`.
// The same tag toggles clock-in and clock-out — the app decides direction based
// on the worker's latest shift_clock_events row (see ClockStore.handleTagRead).
//
// This parser is deliberately paranoid: the reader is armed while the worker
// is on Shifts / Shift detail, and we can't stop random tags from being read.
// Anything that isn't a foodrun.nl clock URL is ignored.
//
// Reused by both the foreground `NFCNDEFReaderSession` callback and, once we
// ship Phase 2, the background `NSUserActivity` handler.

public struct NFCTagAction: Equatable {
    /// Truck slug from `/clock/<slug>`. Empty string is rejected in parse.
    public let truckSlug: String
    /// The full URL that was on the tag — kept for the audit trail in
    /// shift_clock_events.tag_id (or an equivalent server-side log).
    public let sourceURL: URL

    /// Returns nil if the URL is not one of ours. Callers should treat nil as
    /// "ignore this tag, do not surface it to the user."
    public static func parse(_ url: URL) -> NFCTagAction? {
        // Require https + foodrun.nl (or subdomain). The web PWA already sits
        // on foodrun.nl; the association file lives there too when Phase 2
        // ships. Anything else is not our tag.
        guard url.scheme == "https" else { return nil }
        guard let host = url.host?.lowercased(), host == "foodrun.nl" || host.hasSuffix(".foodrun.nl") else {
            return nil
        }

        // Path shape: /clock/<slug>. Slug must be non-empty and simple —
        // rejecting anything with a `..` or `/` inside blocks trivial
        // spoofing attempts written by a rogue tag writer.
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2, parts[0] == "clock" else { return nil }
        let slug = parts[1]
        guard !slug.isEmpty, !slug.contains(".."), !slug.contains("/") else { return nil }

        return NFCTagAction(truckSlug: slug, sourceURL: url)
    }

    /// Convenience for the raw-string overload — the foreground reader hands us
    /// text payloads.
    public static func parse(_ rawURL: String) -> NFCTagAction? {
        guard let url = URL(string: rawURL) else { return nil }
        return parse(url)
    }
}
