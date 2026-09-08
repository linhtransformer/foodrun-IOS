import SwiftUI

// Foodrun 4pt spacing scale.

public enum FRSpacing {
    case xs, sm, md, lg, xl, xxl

    public var value: CGFloat {
        switch self {
        case .xs:  return 4
        case .sm:  return 8
        case .md:  return 12
        case .lg:  return 16
        case .xl:  return 24
        case .xxl: return 32
        }
    }
}

public extension View {
    func padding(_ token: FRSpacing) -> some View {
        self.padding(token.value)
    }

    func padding(_ edges: Edge.Set, _ token: FRSpacing) -> some View {
        self.padding(edges, token.value)
    }
}
