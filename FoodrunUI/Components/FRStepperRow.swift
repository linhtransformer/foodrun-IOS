import SwiftUI

// Bundle §2c "Two stepper rows" — availability mode.
// − / value / + with the + as a black filled circle. Clamp 0…7.

public struct FRStepperRow: View {
    public let label: LocalizedStringKey
    @Binding public var value: Int
    public let range: ClosedRange<Int>

    public init(_ label: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int> = 0...7) {
        self.label = label
        self._value = value
        self.range = range
    }

    public var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .frText(FRType.rowTitle)
            Spacer()
            Button {
                if value > range.lowerBound { value -= 1; FRHaptic.light.fire() }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(value <= range.lowerBound ? Color.foodrun.disabledInk : Color.foodrun.foreground)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.foodrun.neuPill))
            }
            .buttonStyle(.plain)
            .frNeu(.pressed)
            .accessibilityLabel(Text("action.decrement"))
            Text("\(value)")
                .font(.system(size: 20, weight: .heavy).monospacedDigit())
                .frame(minWidth: 32)
            Button {
                if value < range.upperBound { value += 1; FRHaptic.light.fire() }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.foodrun.foreground))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.increment"))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }
}

#Preview("Stepper") {
    struct H: View {
        @State var v = 3
        var body: some View {
            FRStepperRow("availability.wantThisWeek", value: $v)
                .padding(20)
                .background(Color.foodrun.background)
        }
    }
    return H()
}
