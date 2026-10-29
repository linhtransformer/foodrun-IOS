import SwiftUI

// Bundle §"The clock-in interaction". Two overlays:
//   1. TagDetectedFlash — full-screen scrim + 64pt yellow badge with pulsing rings.
//   2. NFCResultSheet — rises 34pt + fades, shows clocked-in or clocked-out result.

public struct TagDetectedFlash: View {
    public let visible: Bool

    public var body: some View {
        ZStack {
            Rectangle().fill(Color(hex: 0x0A0A09).opacity(0.72)).ignoresSafeArea()
            ZStack {
                // Pulsing rings.
                ring().scaleEffect(1.5).opacity(0)
                    .animation(FRAnimation.nfcPulse, value: visible)
                ring().scaleEffect(1.5).opacity(0)
                    .animation(FRAnimation.nfcPulse.delay(0.4), value: visible)
                // Badge.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.foodrun.truck.mees)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Color.foodrun.foreground)
                    )
                    .scaleEffect(visible ? 1 : 0.5)
                    .opacity(visible ? 1 : 0)
                    .animation(FRAnimation.nfcBadgePop, value: visible)
            }
            .accessibilityElement()
            .accessibilityLabel(Text("nfc.tagDetected"))
        }
        .opacity(visible ? 1 : 0)
        .allowsHitTesting(visible)
    }

    private func ring() -> some View {
        Circle()
            .stroke(Color.foodrun.truck.mees.opacity(0.6), lineWidth: 2)
            .frame(width: 64, height: 64)
    }
}

public struct NFCResultSheet: View {
    public let result: ClockStore.NFCResult
    public let clockInTime: String
    public let truckName: String
    public let worked: String?          // "4h 12m" for clock-out
    public let span: String?            // "19:02 – 23:14"
    /// When checklists are off, the clock-in primary button just closes the sheet.
    public var checklistsEnabled: Bool = true
    public var onOpenChecklist: () -> Void
    public var onDismissUndo: () -> Void

    public var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.foodrun.border).frame(width: 40, height: 4).padding(.top, 8)
            badge
            titleLabel
            tiles
            agentNote
            Button(action: onOpenChecklist) {
                Text(primaryCTA)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .frCTAShadow()
            }
            .buttonStyle(.plain)
            // A second "close" only when the black button does something else (open the
            // checklist, review hours); next to "Klaar" it was the same action twice.
            if result != .clockedIn || checklistsEnabled {
                Button(action: onDismissUndo) {
                    Text(secondaryCopy)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.sheetTop.value, style: .continuous)
                .fill(Color.foodrun.background)
                .ignoresSafeArea(edges: .bottom)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.2), radius: 40, y: -10)
    }

    /// Black circle with a white check (in) or flag (out), like the app's black pills; a thin
    /// green ring says "on the clock" after a clock-in.
    private var badge: some View {
        let clockingIn = result == .clockedIn
        return Circle()
            .fill(Color.foodrun.foreground)
            .frame(width: 64, height: 64)
            .overlay(
                Image(systemName: clockingIn ? "checkmark" : "flag.checkered")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
            )
            .padding(5)
            .overlay(
                Circle().strokeBorder(clockingIn ? Color.foodrun.subject.onTheClockGreen : Color.foodrun.border,
                                      lineWidth: 2)
            )
            .accessibilityHidden(true)
    }

    private var titleLabel: some View {
        Text(result == .clockedIn ? "nfc.result.clockedIn" : "nfc.result.clockedOut")
            .frText(FRType.sectionHeader)
    }

    @ViewBuilder
    private var tiles: some View {
        HStack(spacing: 10) {
            tile(label: result == .clockedIn ? "nfc.tile.clockedInAt" : "nfc.tile.workedTotal",
                 value: result == .clockedIn ? clockInTime : (worked ?? "-"))
            tile(label: result == .clockedIn ? "nfc.tile.truck" : "nfc.tile.span",
                 value: result == .clockedIn ? truckName : (span ?? "-"))
        }
    }

    private func tile(label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(value).frText(FRType.rowTitle)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.pressed)
    }

    /// What happens next, as a small black pill with a white outline (was a blue note). Sized to
    /// its text so it reads as a label, not as a second button next to the black CTA.
    private var agentNote: some View {
        Text(result == .clockedIn ? "nfc.agent.clockedIn" : "nfc.agent.clockedOut")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Color.foodrun.backgroundInverseInk)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Capsule().fill(Color.foodrun.foreground))
            .overlay(Capsule().strokeBorder(Color.foodrun.backgroundInverseInk, lineWidth: 1).padding(2))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 320)
    }

    private var primaryCTA: LocalizedStringKey {
        if result == .clockedIn { return checklistsEnabled ? "nfc.cta.openChecklist" : "nfc.cta.done" }
        return "nfc.cta.reviewHours"
    }

    // The clock RPCs have no undo, so the secondary button only closes the sheet
    // and says exactly that (it used to promise "undo clock-in").
    private var secondaryCopy: LocalizedStringKey { "nfc.cta.close" }
}

#Preview("Tag detected") {
    ZStack {
        Color.foodrun.background.ignoresSafeArea()
        TagDetectedFlash(visible: true)
    }
}

#Preview("NFC result — clocked in") {
    VStack {
        Spacer()
        NFCResultSheet(
            result: .clockedIn,
            clockInTime: "19:02",
            truckName: "Truck Mees",
            worked: nil, span: nil,
            onOpenChecklist: {}, onDismissUndo: {}
        )
    }
    .background(Color.foodrun.background)
}
