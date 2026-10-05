import SwiftUI

// Signature recessed-track / raised-pill segmented control.
// Bundle §2 "Mode pills": track #E8E5E0 with paired inset shadow, 6pt padding;
// active pill #FBFAF7 with the raised pair; inactive ink #6A6A6A.

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
        .padding(6)
        .background(
            Capsule().fill(Color.foodrun.neuTrack)
        )
        .overlay(
            // Inset "pressed" look on the track.
            Capsule()
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                .blur(radius: 0.5)
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func pill(_ option: Option) -> some View {
        let active = option == selection
        Text(label(option))
            .frText(FRType.segmented)
            .foregroundStyle(active ? Color.foodrun.foreground : Color(hex: 0x6A6A6A))
            // One line always: long labels ("Beschikbaarheid") shrink a touch instead of wrapping.
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 6)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                Capsule().fill(active ? Color.foodrun.neuPill : .clear)
            )
            .frNeu(active ? .raised : .inset)
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
