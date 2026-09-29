import SwiftUI

// Floating black pill tab bar, 5 items. Bundle §Tab bar.
// Hidden on the sign-in screen; parent controls visibility.

public enum FRTab: String, CaseIterable, Hashable {
    case shifts, tasks, hours, inbox, me

    public var symbol: String {
        switch self {
        case .shifts: return "calendar"
        case .tasks:  return "checklist"
        case .hours:  return "clock"
        case .inbox:  return "message"
        case .me:     return "person"
        }
    }

    public var label: LocalizedStringKey {
        switch self {
        case .shifts: return "tab.shifts"
        case .tasks:  return "tab.tasks"
        case .hours:  return "tab.hours"
        case .inbox:  return "tab.inbox"
        case .me:     return "tab.me"
        }
    }
}

public struct FRTabBar: View {
    @Binding public var selection: FRTab
    public var badgedTabs: Set<FRTab>

    public init(selection: Binding<FRTab>, badgedTabs: Set<FRTab> = []) {
        self._selection = selection
        self.badgedTabs = badgedTabs
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(FRTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                    FRHaptic.light.fire()
                } label: {
                    tabItem(tab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.tabBar.value, style: .continuous)
                .fill(Color.foodrun.foreground)
        )
        .padding(.horizontal, 12)
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func tabItem(_ tab: FRTab) -> some View {
        let active = tab == selection
        VStack(spacing: 3) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tab.symbol)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(active ? Color.foodrun.foreground : Color.foodrun.backgroundInverseInk.opacity(0.55))
                if !active && badgedTabs.contains(tab) {
                    Circle()
                        .fill(Color.foodrun.subject.warning)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.foodrun.foreground, lineWidth: 1.5))
                        .offset(x: 6, y: -4)
                }
            }
            Text(tab.label)
                .frText(FRType.tab)
                .foregroundStyle(active ? Color.foodrun.foreground : Color.foodrun.backgroundInverseInk.opacity(0.55))
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(active ? Color.foodrun.backgroundInverseInk : .clear)
        )
        .accessibilityLabel(Text(tab.label))
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview("Tab bar") {
    struct H: View {
        @State var tab: FRTab = .shifts
        var body: some View {
            VStack {
                Spacer()
                FRTabBar(selection: $tab, badgedTabs: [.hours, .inbox])
                    .padding(.bottom, 22)
            }
            .frame(width: 402, height: 300)
            .background(Color.foodrun.background)
        }
    }
    return H()
}
