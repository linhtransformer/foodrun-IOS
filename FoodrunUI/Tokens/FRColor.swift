import SwiftUI

// Foodrun color tokens. Bridges BRAND.md hex values to SwiftUI.
//
// v1: light-mode only. Hex values embedded directly. Both light and dark
// values recorded here so v2 dark-mode wiring is a token-file edit, not
// a source-wide sweep.
//
// Rules mirrored from BRAND.md:
//  * Anchor palette: #F4F5F0 / #1A1A1A / #FFFFFF only. No pure #000000
//    outside logo asset.
//  * Subject colors are for tints (borders, chips, single numbers) — not
//    for the primary CTA. The primary CTA stays foreground/near-black.

public extension Color {
    struct Foodrun {
        // Anchor palette
        public let background = Color(hex: 0xF4F5F0) // off-white canvas
        public let foreground = Color(hex: 0x1A1A1A) // near-black ink
        public let surface = Color(hex: 0xFFFFFF)    // floating white surface
        public let card = Color(hex: 0xF4F5F0)       // soft-UI card fill
        public let mutedForeground = Color(hex: 0x6B6B6B)
        public let border = Color(hex: 0xE7E7E1)

        public let subject = Subject()

        public struct Subject {
            public let revenue = Color(hex: 0x16A34A)
            public let cost = Color(hex: 0xE11D48)
            public let cash = Color(hex: 0xCA8A04)
            public let orders = Color(hex: 0x2563EB)
            public let forecast = Color(hex: 0x7C3AED)
            public let alert = Color(hex: 0xD97706)
            public let info = Color(hex: 0x0891B2)
        }
    }

    static let foodrun = Foodrun()
}

// Hex initializer restricted to token files — SwiftLint rule will forbid
// Color(hex:) usage in consumer code (see spec §10).
extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xff) / 255
        let g = Double((hex >> 8) & 0xff) / 255
        let b = Double(hex & 0xff) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}
