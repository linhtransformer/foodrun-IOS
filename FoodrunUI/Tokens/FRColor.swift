import SwiftUI
import UIKit

// Foodrun color tokens. Bridges BRAND.md + the design-handoff bundle to SwiftUI.
//
// Light and dark (Ik → Instellingen → Weergave): the neutral tokens below carry both
// values and follow the screen's color scheme. Black pills turn light in the dark —
// `foreground` / `backgroundInverseInk` swap together. Truck and semantic colours stay.
//
// Rules:
//  * Anchor palette: #F8F7F5 (canvas) / #1A1A1A (ink) / #FFFFFF (surface).
//    No pure #000000 outside the logo asset.
//  * `Color(hex:)` is restricted to this file — SwiftLint rule enforces it.
//  * Truck palette is tint-only (chips, dots, borders). Never a CTA fill.

public extension Color {
    struct Foodrun {
        // Anchor palette (bundle §Token reconciliation).
        public let background = Color(light: 0xF8F7F5, dark: 0x111110)          // warm canvas (was #F3F1EF)
        public let foreground = Color(light: 0x1A1A1A, dark: 0xF2F1EE)
        public let surface = Color(light: 0xFFFFFF, dark: 0x1C1C1B)             // floating white cards
        public let card = Color(light: 0xFFFFFF, dark: 0x1E1E1D)                // was #F4F5F0
        public let border = Color(light: 0xE0DDD9, dark: 0x34332F)              // was #E7E7E1

        /// The black tab bar: stays dark in dark mode too (a lighter black, so it still lifts
        /// off the canvas), with its own light ink. Today's shift card inverts instead (light).
        public let chrome = Color(light: 0x1A1A1A, dark: 0x2A2A28)
        public let chromeInk = Color(light: 0xF4F5F0, dark: 0xF2F1EE)
        /// A switch that is on: black on the light canvas, green in the dark (a light track
        /// with a white knob can't be seen).
        public let toggleOn = Color(light: 0x1A1A1A, dark: 0x16A34A)

        // Ink on the black hero (retired old card value — kept for that one purpose).
        public let backgroundInverseInk = Color(light: 0xF4F5F0, dark: 0x161615)

        // Secondary / tertiary label ink (bundle §Token reconciliation).
        public let mutedForeground = Color(light: 0x6B6B6B, dark: 0xA8A8A6)
        public let mutedForegroundSoft = Color(light: 0x8A8A8A, dark: 0x8F8F8C) // row subtitles, footers
        public let bodySoft = Color(light: 0x5C5C5C, dark: 0xB8B8B5)            // tertiary body
        public let disabledInk = Color(light: 0xC9C4BE, dark: 0x4A4844)

        // Neumorphic surfaces.
        public let neuTrack = Color(light: 0xE8E5E0, dark: 0x272725)            // recessed segmented track
        public let neuPill = Color(light: 0xFBFAF7, dark: 0x2E2E2C)             // raised active pill
        /// The light edge of the soft-UI shadow: white on the off-white ground, barely there in
        /// the dark (a white glow on a dark card looks like a smudge).
        public let neuHighlight = Color(lightRGBA: (1, 1, 1, 0.9), darkRGBA: (1, 1, 1, 0.03))
        public let neuShadowDark = Color(light: 0xD1CECA, dark: 0x000000)

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
    /// A token that follows light / dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { trait in
            UIColor(Color(hex: trait.userInterfaceStyle == .dark ? dark : light))
        })
    }

    init(lightRGBA: (Double, Double, Double, Double), darkRGBA: (Double, Double, Double, Double)) {
        self.init(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? darkRGBA : lightRGBA
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: c.3)
        })
    }

    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
