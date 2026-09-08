import SwiftUI

// Foodrun radius scale. Mirrors design-system.md §Radius.
// Arbitrary radii are banned in consumer code (SwiftLint rule).

public enum FRRadius {
    case row       // 12pt — inputs, rows, small chips
    case card      // 16pt — standard cards
    case container // 20pt — large containers, KPI blocks
    case shell     // 24pt — floating shells, sheets
    case pill      // infinity — buttons, badges (use Capsule instead)

    public var value: CGFloat {
        switch self {
        case .row:       return 12
        case .card:      return 16
        case .container: return 20
        case .shell:     return 24
        case .pill:      return .infinity
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
