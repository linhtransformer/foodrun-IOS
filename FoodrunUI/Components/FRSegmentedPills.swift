import SwiftUI

// Segmented control: white raised track, active option a black pill — the
// same style as the shift screen's tabs (ShiftDetailView.tabPicker).

public struct FRSegmentedPills<Option: Hashable>: View {
    public let options: [Option]
    public let label: (Option) -> LocalizedStringKey
    @Binding public var selection: Option

    public init(_ options: [Option], selection: Binding<Option>, label: @escaping (Option) -> LocalizedStringKey) {
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(FRAnimation.subtle) { selection = option }
                    FRHaptic.light.fire()
                } label: {
                    pill(option)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.foodrun.card))
        .frNeu(.raised)
        .accessibilityElement(children: .contain)
    }

    // Same look as the shift screen's Draaiboek / Setup / Taken tabs:
    // white track, active option a black pill with light text.
    @ViewBuilder
    private func pill(_ option: Option) -> some View {
        let active = option == selection
        Text(label(option))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
            // One line always: long labels ("Beschikbaarheid") shrink a touch instead of wrapping.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(Capsule().fill(active ? Color.foodrun.foreground : Color.clear))
            .contentShape(Capsule())
            .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview("Segmented pills") {
    struct H: View {
        @State var mode: ScheduleStore.ShiftsMode = .shifts
        var body: some View {
            FRSegmentedPills(
                ScheduleStore.ShiftsMode.allCases,
                selection: $mode
            ) { m in
                switch m {
                case .shifts:       return "mode.shifts"
                case .roster:       return "mode.roster"
                case .availability: return "mode.availability"
                }
            }
            .padding(20)
            .background(Color.foodrun.background)
        }
    }
    return H()
}
