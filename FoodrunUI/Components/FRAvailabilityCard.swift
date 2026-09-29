import SwiftUI

// Bundle §2c "Day card" — the availability day card with dual-handle slider.
// 22pt radius, .raisedLg. Range readout, dual-handle, scale, state buttons, reason.

public struct FRAvailabilityCard: View {
    public let date: Date
    @Binding public var window: ClosedRange<Int>       // hours 0…24
    @Binding public var state: AvailabilityStore.State
    @Binding public var reason: String

    public var body: some View {
        VStack(spacing: 16) {
            rangeReadout
            DualHandleSlider(
                range: $window,
                bounds: 0...24,
                minSpan: 1,
                accent: state == .available ? Color.foodrun.subject.positive :
                         state == .unavailable ? Color.foodrun.subject.destructive :
                         Color.foodrun.mutedForegroundSoft
            )
            .frame(height: 44)
            scale
            stateButtons
            reasonField
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.hero.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raisedLg)
    }

    private var rangeReadout: some View {
        VStack(spacing: 4) {
            Text("\(hh(window.lowerBound)) – \(hh(window.upperBound))")
                .font(.system(size: 36, weight: .heavy).monospacedDigit())
                .tracking(-1)
            Text(dateLine)
                .font(.system(size: 12))
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private var scale: some View {
        HStack {
            Text("00:00").frText(FRType.rowSubtitle)
            Spacer()
            Text("12:00").frText(FRType.rowSubtitle)
            Spacer()
            Text("24:00").frText(FRType.rowSubtitle)
        }
        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
    }

    private var stateButtons: some View {
        HStack(spacing: 10) {
            stateButton(.unavailable,
                        label: "availability.notAvailable",
                        activeFill: Color.foodrun.subject.destructive)
            stateButton(.available,
                        label: "availability.available",
                        activeFill: Color.foodrun.subject.positive)
        }
    }

    @ViewBuilder
    private func stateButton(_ target: AvailabilityStore.State, label: LocalizedStringKey, activeFill: Color) -> some View {
        let active = state == target
        Button {
            state = target; FRHaptic.medium.fire()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color(hex: 0x6A6A6A))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(active ? activeFill : Color.foodrun.background)
                )
                .frNeu(active ? .raised : .pressed)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }

    private var reasonField: some View {
        HStack {
            TextField(text: $reason) {
                Text("availability.reason.placeholder")
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            .font(.system(size: 14))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.foodrun.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.foodrun.border, lineWidth: 1)
        )
    }

    private var dateLine: String {
        let f = DateFormatter(); f.dateFormat = "d-M-yyyy"
        return f.string(from: date)
    }
    private func hh(_ hour: Int) -> String { String(format: "%02d:00", hour) }
}

// MARK: - Dual-handle slider (custom, since two overlaid `Slider`s won't work).

struct DualHandleSlider: View {
    @Binding var range: ClosedRange<Int>
    let bounds: ClosedRange<Int>
    let minSpan: Int
    let accent: Color

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let total = CGFloat(bounds.upperBound - bounds.lowerBound)
            func x(_ v: Int) -> CGFloat { width * CGFloat(v - bounds.lowerBound) / total }
            let lowX = x(range.lowerBound)
            let highX = x(range.upperBound)

            ZStack(alignment: .leading) {
                // Track.
                Capsule().fill(Color.foodrun.neuTrack).frame(height: 5)
                // Filled segment.
                Capsule().fill(accent)
                    .frame(width: max(0, highX - lowX), height: 5)
                    .offset(x: lowX)
                // Low handle.
                handle(color: accent)
                    .position(x: lowX, y: geo.size.height / 2)
                    .gesture(dragGesture(width: width, isLow: true))
                    .accessibilityLabel(Text("availability.slider.start"))
                    .accessibilityValue(Text(String(range.lowerBound)))
                // High handle.
                handle(color: accent)
                    .position(x: highX, y: geo.size.height / 2)
                    .gesture(dragGesture(width: width, isLow: false))
                    .accessibilityLabel(Text("availability.slider.end"))
                    .accessibilityValue(Text(String(range.upperBound)))
            }
        }
    }

    private func handle(color: Color) -> some View {
        Circle()
            .fill(color)
            .overlay(Circle().stroke(Color.foodrun.surface, lineWidth: 3))
            .frame(width: 22, height: 22)
            .contentShape(Rectangle().size(width: 44, height: 44))
            .shadow(color: .black.opacity(0.28), radius: 3, y: 2)
    }

    private func dragGesture(width: CGFloat, isLow: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { g in
                let total = CGFloat(bounds.upperBound - bounds.lowerBound)
                let raw = Int(round((g.location.x / width) * total)) + bounds.lowerBound
                if isLow {
                    let clamped = min(range.upperBound - minSpan, max(bounds.lowerBound, raw))
                    if clamped != range.lowerBound {
                        range = clamped...range.upperBound
                        FRHaptic.light.fire()
                    }
                } else {
                    let clamped = max(range.lowerBound + minSpan, min(bounds.upperBound, raw))
                    if clamped != range.upperBound {
                        range = range.lowerBound...clamped
                        FRHaptic.light.fire()
                    }
                }
            }
    }
}

#Preview("Availability card") {
    struct H: View {
        @State var window: ClosedRange<Int> = 7...15
        @State var state: AvailabilityStore.State = .available
        @State var reason = ""
        var body: some View {
            FRAvailabilityCard(date: Fixtures.today, window: $window, state: $state, reason: $reason)
                .padding(20)
                .background(Color.foodrun.background)
        }
    }
    return H()
}
