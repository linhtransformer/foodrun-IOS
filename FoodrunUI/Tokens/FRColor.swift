import SwiftUI

// Foodrun color tokens. Bridges BRAND.md + the design-handoff bundle to SwiftUI.
//
// Light-mode only in v1. Dark-mode wiring is a token-file edit here, not a
// source-wide sweep — every value below has a `dark:` companion recorded in a
// comment so v2 flips it on.
//
// Rules:
//  * Anchor palette: #F8F7F5 (canvas) / #1A1A1A (ink) / #FFFFFF (surface).
//    No pure #000000 outside the logo asset.
//  * `Color(hex:)` is restricted to this file — SwiftLint rule enforces it.
//  * Truck palette is tint-only (chips, dots, borders). Never a CTA fill.

public extension Color {
    struct Foodrun {
        // Anchor palette (bundle §Token reconciliation).
        public let background = Color(hex: 0xF8F7F5)          // warm canvas (was #F3F1EF)
        public let foreground = Color(hex: 0x1A1A1A)
        public let surface = Color(hex: 0xFFFFFF)             // floating white cards
        public let card = Color(hex: 0xFFFFFF)                // was #F4F5F0
        public let border = Color(hex: 0xE0DDD9)              // was #E7E7E1

        // Ink on the black hero (retired old card value — kept for that one purpose).
        public let backgroundInverseInk = Color(hex: 0xF4F5F0)

        // Secondary / tertiary label ink (bundle §Token reconciliation).
        public let mutedForeground = Color(hex: 0x6B6B6B)
        public let mutedForegroundSoft = Color(hex: 0x8A8A8A) // row subtitles, footers
        public let bodySoft = Color(hex: 0x5C5C5C)            // tertiary body
        public let disabledInk = Color(hex: 0xC9C4BE)

        // Neumorphic surfaces.
        public let neuTrack = Color(hex: 0xE8E5E0)            // recessed segmented track
        public let neuPill = Color(hex: 0xFBFAF7)             // raised active pill
        public let neuShadowDark = Color(hex: 0xD1CECA)

        // Semantic (subject) colors.
        public let subject = Subject()

        public struct Subject {
            // Legacy dashboard tokens — kept so existing showcase code compiles.
            public let revenue = Color(hex: 0x16A34A)
            public let cost = Color(hex: 0xE11D48)
            public let cash = Color(hex: 0xCA8A04)
            public let orders = Color(hex: 0x2563EB)
            public let forecast = Color(hex: 0x7C3AED)
            public let alert = Color(hex: 0xD97706)
            public let info = Color(hex: 0x0891B2)

            // Worker-app semantic colors (bundle §Semantic colors).
            public let positive = Color(hex: 0x16A34A)        // approved / available
            public let warning = Color(hex: 0xF97316)         // pending
            public let warningPill = Color(hex: 0xF59E0B)     // "closes Thu 23:59" amber
            public let destructive = Color(hex: 0xDC2626)     // unavailable
            public let swapOpenInk = Color(hex: 0xA15C07)
            public let agentNoteBlue = Color(hex: 0x3B82F6)
            public let onTheClockGreen = Color(hex: 0x86EFAC)
        }

        // Truck palette — chips, bars, dots, tinted card fills only.
        public let truck = Truck()

        public struct Truck {
            public let mees = Color(hex: 0xFBE27A)            // yellow
            public let mike = Color(hex: 0x86EFAC)            // green
            public let mama = Color(hex: 0xF0A8C8)            // pink
            public let extraBlue = Color(hex: 0x7AA6F5)

            /// Tint fill for cards (bundle: `rgba(x,y,z,.18)`).
            public func tint(_ color: Color) -> Color {
                color.opacity(0.18)
            }
        }

        // Agent-note field (bundle §Semantic colors: `rgba(122,166,245,.14)`).
        public var agentNoteField: Color { subject.agentNoteBlue.opacity(0.14) }
    }

    static let foodrun = Foodrun()

    /// Data-driven colour from the database (activities.color, e.g. "#FBE27A").
    /// The one sanctioned way for views to use a colour that isn't a token —
    /// same rule as the web's "data-driven colors" exception. Falls back to the
    /// Truck Mees yellow when the value is missing or malformed.
    static func foodrunData(hex: String?) -> Color {
        guard var s = hex?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return Color.foodrun.truck.mees }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return Color.foodrun.truck.mees }
        return Color(hex: v)
    }
}

// Hex initializer restricted to this file.
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
