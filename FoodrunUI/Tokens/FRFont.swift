import SwiftUI

// Foodrun typography tokens. Every case renders SF Pro via `.system(...)` —
// Apple licence forbids bundling fonts. The bundle's prototype uses Cabinet
// Grotesk + Inter; we map those roles to SF Pro weights + tracking per the
// handoff §Typography table.
//
// Every numeric role uses `.monospacedDigit()` — time values, hour counts,
// dates, and counters must be tabular.

public extension Font {
    struct Foodrun {
        // Legacy — kept so existing HomeView showcase compiles.
        public let pageTitle: Font = .system(.largeTitle, design: .default).weight(.semibold)
        public let sectionTitle: Font = .system(.headline, design: .default).weight(.semibold)
        public let body: Font = .system(.body, design: .default)
        public let caption: Font = .system(.caption, design: .default)
        public let tabularNumbers: Font = .system(.body, design: .default).monospacedDigit()

        // Worker-app roles (bundle §Typography).
        public let screenTitle: Font = .system(size: 28, weight: .bold)          // + .tracking(-0.8)
        public let heroClock: Font = .system(size: 52, weight: .heavy)           // + .tracking(-2) + .monospacedDigit()
        public let heroClockCompact: Font = .system(size: 26, weight: .heavy)    // collapsed hero
        public let kpiNumber: Font = .system(size: 34, weight: .heavy).monospacedDigit() // + .tracking(-1)
        public let kpiNumberLg: Font = .system(size: 40, weight: .heavy).monospacedDigit()
        public let sectionHeader: Font = .system(size: 18, weight: .bold)        // + .tracking(-0.4)
        public let eyebrow: Font = .system(size: 10, weight: .heavy)             // + .tracking(2.5) + .uppercase
        public let screenKicker: Font = .system(size: 11, weight: .semibold)     // + .tracking(2)
        public let fieldLabel: Font = .system(size: 10.5, weight: .bold)         // + .tracking(1.5)
        public let rowTitle: Font = .system(size: 14, weight: .semibold)
        public let rowSubtitle: Font = .system(size: 12)
        public let body135: Font = .system(size: 13.5)                           // + .lineSpacing(3)
        public let segmentedLabel: Font = .system(size: 12.5, weight: .semibold)
        public let tabLabel: Font = .system(size: 9.5, weight: .semibold)

        // Convenience for time strings on the hero.
        public let heroSub: Font = .system(size: 17, weight: .semibold).monospacedDigit()
        public let heroClockLive: Font = .system(size: 38, weight: .heavy).monospacedDigit()
    }

    static let foodrun = Foodrun()
}

// Text tracking convenience — SwiftUI's `.tracking` lives on Text, not Font.
// This modifier + `frText(_:)` bundles the two so consumers can write
//   Text("Hey Sanne").frText(\.screenTitle)
// and pick up both the font AND the tracking without leaking magic numbers.
public struct FRTextRole {
    public let font: Font
    public let tracking: CGFloat
    public let uppercase: Bool
    public let lineSpacing: CGFloat?
    public init(font: Font, tracking: CGFloat = 0, uppercase: Bool = false, lineSpacing: CGFloat? = nil) {
        self.font = font
        self.tracking = tracking
        self.uppercase = uppercase
        self.lineSpacing = lineSpacing
    }
}

public enum FRType {
    public static let screenTitle    = FRTextRole(font: .foodrun.screenTitle, tracking: -0.8)
    public static let heroClock      = FRTextRole(font: .foodrun.heroClock, tracking: -2)
    public static let heroClockCompact = FRTextRole(font: .foodrun.heroClockCompact, tracking: -0.6)
    public static let heroClockLive  = FRTextRole(font: .foodrun.heroClockLive, tracking: -1)
    public static let heroSub        = FRTextRole(font: .foodrun.heroSub)
    public static let kpi            = FRTextRole(font: .foodrun.kpiNumber, tracking: -1)
    public static let kpiLg          = FRTextRole(font: .foodrun.kpiNumberLg, tracking: -1.2)
    public static let sectionHeader  = FRTextRole(font: .foodrun.sectionHeader, tracking: -0.4)
    public static let eyebrow        = FRTextRole(font: .foodrun.eyebrow, tracking: 2.5, uppercase: true)
    public static let kicker         = FRTextRole(font: .foodrun.screenKicker, tracking: 2, uppercase: true)
    public static let fieldLabel     = FRTextRole(font: .foodrun.fieldLabel, tracking: 1.5, uppercase: true)
    public static let rowTitle       = FRTextRole(font: .foodrun.rowTitle)
    public static let rowSubtitle    = FRTextRole(font: .foodrun.rowSubtitle)
    public static let body           = FRTextRole(font: .foodrun.body135, lineSpacing: 3)
    public static let segmented      = FRTextRole(font: .foodrun.segmentedLabel)
    public static let tab            = FRTextRole(font: .foodrun.tabLabel)
}

public extension View {
    /// Apply an FRType role — sets font, tracking, uppercase, line spacing in one call.
    func frText(_ role: FRTextRole) -> some View {
        self.font(role.font)
            .tracking(role.tracking)
            .textCase(role.uppercase ? .uppercase : nil)
            .lineSpacing(role.lineSpacing ?? 0)
    }
}
