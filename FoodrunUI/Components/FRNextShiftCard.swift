import SwiftUI

// The black hero on Shifts. Bundle §2 "Next-shift hero".
// Two states: collapsed (opens by default) and expanded (52pt clock + clock panel).

public struct FRNextShiftCard: View {
    public let start: String            // "19:00"
    public let end: String              // "23:00"
    public let dayLabel: String         // "Wed"
    public let role: String             // "Kitchen"
    public let truckName: String        // "Truck Mees"
    public let truckColor: Color
    public let location: String
    public let clockedIn: Bool
    public let elapsed: TimeInterval    // seconds since clock-in
    public let plannedDuration: TimeInterval // total shift duration in seconds
    @Binding public var expanded: Bool
    public var onTapListening: () -> Void
    public var onTapChecklist: () -> Void
    public var checklistProgress: (Int, Int)   // done / total

    public var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: FRRadius.hero.value, style: .continuous)
                .fill(Color.foodrun.foreground)

            // Toggle pill — top-right corner (was top-center; freed the vertical space).
            Button {
                withAnimation(FRAnimation.subtle) { expanded.toggle() }
                FRHaptic.light.fire()
            } label: {
                Image(systemName: expanded ? "minus" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.foodrun.backgroundInverseInk.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(Text(expanded ? "hero.collapse" : "hero.expand"))
            .zIndex(2)

            Group {
                if expanded {
                    VStack(alignment: .leading, spacing: 12) {
                        topRow
                        expandedBody
                    }
                    .padding(20)
                } else {
                    collapsedBody
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 44))
                }
            }
            .foregroundStyle(Color.foodrun.backgroundInverseInk)
        }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }

    // MARK: - Fragments

    private var topRow: some View {
        HStack(spacing: 10) {
            Text("hero.eyebrow.nextShift")
                .frText(FRType.eyebrow)
                .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.65))
            HStack(spacing: 6) {
                Circle().fill(truckColor).frame(width: 7, height: 7)
                Text(truckName)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Capsule().fill(Color.foodrun.backgroundInverseInk.opacity(0.10)))
            Spacer(minLength: 0)
        }
    }

    private var collapsedBody: some View {
        // Two tight rows: (eyebrow · truck dot · truck name · optional timer) then (time + day · role).
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("hero.eyebrow.nextShift")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(2.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
                Circle().fill(truckColor).frame(width: 6, height: 6)
                Text(truckName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.85))
                Spacer(minLength: 0)
                if clockedIn {
                    HStack(spacing: 5) {
                        Circle().fill(Color.foodrun.subject.onTheClockGreen).frame(width: 6, height: 6)
                        Text(formatClock(elapsed))
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Color.foodrun.subject.onTheClockGreen)
                    }
                }
            }
            HStack(spacing: 8) {
                Text("\(start) – \(end)")
                    .font(.system(size: 20, weight: .heavy).monospacedDigit())
                    .tracking(-0.4)
                Text("\(dayLabel) · \(role)")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.6))
            }
        }
    }

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(start)
                    .frText(FRType.heroClock)
                    .monospacedDigit()
                Text("– \(end)")
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.7))
            }
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 12))
                Text(location)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.7))
            }
            if clockedIn { clockPanel }
            buttonsRow
        }
    }

    private var clockPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Color.foodrun.subject.onTheClockGreen).frame(width: 8, height: 8)
                Text("hero.onTheClock")
                    .frText(FRType.eyebrow)
                    .foregroundStyle(Color.foodrun.subject.onTheClockGreen)
                Spacer()
                Text("hero.since \(start)")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
            }
            Text(formatClock(elapsed))
                .frText(FRType.heroClockLive)
            let remaining = max(0, plannedDuration - elapsed)
            Text("hero.of \(formatDuration(plannedDuration)) · \(formatDuration(remaining)) left")
                .font(.system(size: 11))
                .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
            ProgressView(value: min(1, elapsed / max(1, plannedDuration)))
                .progressViewStyle(.linear)
                .tint(Color.foodrun.subject.onTheClockGreen)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.backgroundInverseInk.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .stroke(Color.foodrun.subject.onTheClockGreen.opacity(0.28), lineWidth: 1)
        )
    }

    private var buttonsRow: some View {
        HStack(spacing: 10) {
            Button(action: onTapListening) {
                HStack(spacing: 8) {
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 15, weight: .medium))
                    Text("hero.nfc.listening")
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.foodrun.backgroundInverseInk.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4]))
                )
            }
            .buttonStyle(.plain)

            Button(action: onTapChecklist) {
                HStack(spacing: 6) {
                    Image(systemName: checklistProgress.0 == checklistProgress.1 ? "checkmark" : "lock.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text("\(checklistProgress.0)/\(checklistProgress.1)")
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(minHeight: 44)
                .overlay(
                    Capsule().stroke(Color.foodrun.backgroundInverseInk.opacity(0.28), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("hero.checklist"))
        }
    }

    // MARK: - Format

    private func formatClock(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }

    private func formatDuration(_ t: TimeInterval) -> String {
        let h = Int(t) / 3600
        let m = (Int(t) % 3600) / 60
        return "\(h)h \(String(format: "%02d", m))m"
    }
}

#Preview("Next-shift hero, collapsed") {
    struct H: View {
        @State var expanded = false
        var body: some View {
            FRNextShiftCard(
                start: "19:00", end: "23:00", dayLabel: "Wed", role: "Kitchen",
                truckName: "Truck Mees", truckColor: Color.foodrun.truck.mees,
                location: "Paradigm Festival · Steenwijk",
                clockedIn: false, elapsed: 0, plannedDuration: 4 * 3600,
                expanded: $expanded,
                onTapListening: {}, onTapChecklist: {},
                checklistProgress: (3, 7)
            )
            .padding(20)
            .background(Color.foodrun.background)
        }
    }
    return H()
}

#Preview("Next-shift hero, expanded + on the clock") {
    struct H: View {
        @State var expanded = true
        var body: some View {
            FRNextShiftCard(
                start: "19:00", end: "23:00", dayLabel: "Wed", role: "Kitchen",
                truckName: "Truck Mees", truckColor: Color.foodrun.truck.mees,
                location: "Paradigm Festival · Steenwijk",
                clockedIn: true, elapsed: 2 * 3600 + 14 * 60, plannedDuration: 4 * 3600,
                expanded: $expanded,
                onTapListening: {}, onTapChecklist: {},
                checklistProgress: (3, 7)
            )
            .padding(20)
            .background(Color.foodrun.background)
        }
    }
    return H()
}
