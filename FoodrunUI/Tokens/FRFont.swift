import SwiftUI

// Foodrun typography tokens. Uses `.system(...)` so text renders SF Pro
// on iOS without bundling the font (Apple licence permits system stack
// use only). Mirrors BRAND.md §3.

public extension Font {
    struct Foodrun {
        public let pageTitle: Font = .system(.largeTitle, design: .default).weight(.semibold)
        public let sectionTitle: Font = .system(.headline, design: .default).weight(.semibold)
        public let body: Font = .system(.body, design: .default)
        public let caption: Font = .system(.caption, design: .default)
        public let tabularNumbers: Font = .system(.body, design: .default).monospacedDigit()
    }

    static let foodrun = Foodrun()
}
