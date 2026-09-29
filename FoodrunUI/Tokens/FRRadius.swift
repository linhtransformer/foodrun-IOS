import SwiftUI

// Foodrun radius scale. Mirrors design-system.md §Radius and bundle §Shape & elevation.
// Arbitrary radii are banned in consumer code (SwiftLint rule).

public enum FRRadius {
    // Legacy scale.
    case row       // 12pt — inputs, rows, small chips
    case card      // 16pt — standard cards
    case container // 20pt — large containers, KPI blocks
    case shell     // 24pt — floating shells, sheets
    case pill      // infinity — buttons, badges (use Capsule instead)

    // Worker-app additions (bundle §Shape & elevation).
    case hero          // 22pt — hero card, availability day card
    case sheetTop      // 26pt — sheet top corners only
    case tabBar        // 26pt — floating tab bar
    case listRowSm     // 14pt — dense compact rows
    case listRowLg     // 18pt — standard list-row cards
    case inner10       // 10pt — inner tile, month cell
    case dayCell       // 12pt — carousel day cell

    public var value: CGFloat {
        switch self {
        case .row:        return 12
        case .card:       return 16
        case .container:  return 20
        case .shell:      return 24
        case .pill:       return .infinity
        case .hero:       return 22
        case .sheetTop:   return 26
        case .tabBar:     return 26
        case .listRowSm:  return 14
        case .listRowLg:  return 18
        case .inner10:    return 10
        case .dayCell:    return 12
        }
    }

    public var shape: some Shape {
        switch self {
        case .pill:
            return AnyShape(Capsule())
        default:
            return AnyShape(RoundedRectangle(cornerRadius: value, style: .continuous))
        }
    }
}

// Type-erased Shape used by FRRadius.shape.
struct AnyShape: Shape {
    private let path: (CGRect) -> Path
    init<S: Shape>(_ wrapped: S) {
        self.path = wrapped.path(in:)
    }
    func path(in rect: CGRect) -> Path {
        path(rect)
    }
}
