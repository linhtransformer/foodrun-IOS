import SwiftUI

// Foodrun 4pt spacing scale. Worker-app additions (bundle §Shape & elevation)
// live alongside the generic scale.

public enum FRSpacing {
    case xs, sm, md, lg, xl, xxl

    // Worker-app named constants — encode the bundle's paddings so screens don't
    // sprinkle magic numbers.
    case screenH        // 20pt — base horizontal padding on every screen
    case screenTop      // 60pt — top clearance (below status bar)
    case screenBottom   // 108pt — floating tab bar clearance
    case rowGap         // 8pt — between cards
    case denseGap       // 6pt — between compact rows
    case sectionGap     // 22pt — between sections
    case sectionHeadGap // 10pt — section header to first row

    public var value: CGFloat {
        switch self {
        case .xs:              return 4
        case .sm:              return 8
        case .md:              return 12
        case .lg:              return 16
        case .xl:              return 24
        case .xxl:             return 32
        case .screenH:         return 20
        case .screenTop:       return 60
        case .screenBottom:    return 108
        case .rowGap:          return 8
        case .denseGap:        return 6
        case .sectionGap:      return 22
        case .sectionHeadGap:  return 10
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
