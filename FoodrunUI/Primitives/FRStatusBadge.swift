import SwiftUI

public enum FRTone {
    case neutral
    case revenue
    case cost
    case cash
    case orders
    case forecast
    case alert
    case info

    var fill: Color {
        switch self {
        case .neutral:  return Color.foodrun.foreground.opacity(0.08)
        case .revenue:  return Color.foodrun.subject.revenue.opacity(0.14)
        case .cost:     return Color.foodrun.subject.cost.opacity(0.14)
        case .cash:     return Color.foodrun.subject.cash.opacity(0.14)
        case .orders:   return Color.foodrun.subject.orders.opacity(0.14)
        case .forecast: return Color.foodrun.subject.forecast.opacity(0.14)
        case .alert:    return Color.foodrun.subject.alert.opacity(0.14)
        case .info:     return Color.foodrun.subject.info.opacity(0.14)
        }
    }

    var ink: Color {
        switch self {
        case .neutral:  return Color.foodrun.foreground
        case .revenue:  return Color.foodrun.subject.revenue
        case .cost:     return Color.foodrun.subject.cost
        case .cash:     return Color.foodrun.subject.cash
        case .orders:   return Color.foodrun.subject.orders
        case .forecast: return Color.foodrun.subject.forecast
        case .alert:    return Color.foodrun.subject.alert
        case .info:     return Color.foodrun.subject.info
        }
    }
}

public struct FRStatusBadge: View {
    let tone: FRTone
    let label: String

    public init(tone: FRTone, label: String) {
        self.tone = tone
        self.label = label
    }

    public var body: some View {
        Text(label)
            .font(Font.foodrun.caption.weight(.semibold))
            .foregroundStyle(tone.ink)
            .padding(.horizontal, FRSpacing.sm.value)
            .padding(.vertical, 4)
            .background(Capsule().fill(tone.fill))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 8) {
        FRStatusBadge(tone: .revenue, label: "Goedgekeurd")
        FRStatusBadge(tone: .cost, label: "Afgewezen")
        FRStatusBadge(tone: .alert, label: "In behandeling")
        FRStatusBadge(tone: .orders, label: "Actief")
        FRStatusBadge(tone: .neutral, label: "Concept")
    }
    .padding()
    .background(Color.foodrun.background)
}
