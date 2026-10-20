import SwiftUI

// Offer one of my shifts: to one colleague or to everyone, with a short reason.
// request_shift_swap tells the colleague(s); the planner approves in HQ unless the
// employer lets swaps happen at once (Rooster → Instellingen).

public struct SwapOfferSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwapStore.self) private var swaps

    let shift: SwapShift
    @State private var colleague: UUID?
    @State private var note = ""

    public init(shift: SwapShift) {
        self.shift = shift
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("swap.title").frText(FRType.sectionHeader)
            Text(verbatim: "\(shift.activity.title) · \(PeopleFormat.day(shift.day)) · \(PeopleFormat.window(shift.window))")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)

            ScrollView {
                VStack(spacing: 8) {
                    choice(nil, title: Text("swap.everyone"), subtitle: Text("swap.everyone.body"))
                    ForEach(swaps.colleagues(ownerId: shift.owner_id)) { c in
                        choice(c.id, title: Text(verbatim: c.name), subtitle: nil, color: c.color)
                    }
                }
            }
            .frame(maxHeight: 280)

            TextField(text: $note, prompt: Text("swap.note.placeholder")) { Text("swap.note.placeholder") }
                .font(.system(size: 15))
                .padding(12)
                .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))

            if let error = swaps.lastError {
                Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
            }

            Button {
                Task {
                    if await swaps.offer(activityId: shift.activity.id, day: shift.day, to: colleague, note: note.trimmingCharacters(in: .whitespacesAndNewlines)) {
                        FRHaptic.success.fire()
                        dismiss()
                    } else {
                        FRHaptic.error.fire()
                    }
                }
            } label: {
                Text("swap.send")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .frCTAShadow()
            }
            .buttonStyle(.plain)
            .disabled(swaps.busy)
        }
        .padding(20)
        .background(Color.foodrun.background.ignoresSafeArea(edges: .bottom))
        .task { if swaps.board.colleagues.isEmpty { await swaps.load() } }
    }

    private func choice(_ id: UUID?, title: Text, subtitle: Text?, color: String? = nil) -> some View {
        let on = colleague == id
        return HStack(spacing: 12) {
            Circle()
                .fill(id == nil ? Color.foodrun.foreground.opacity(0.08) : Color.foodrunData(hex: color))
                .frame(width: 34, height: 34)
                .overlay(Image(systemName: id == nil ? "person.3" : "person").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.foodrun.foreground))
            VStack(alignment: .leading, spacing: 2) {
                title.frText(FRType.rowTitle)
                if let subtitle {
                    subtitle.frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            Spacer()
            if on {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.foodrun.foreground)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .overlay(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .stroke(on ? Color.foodrun.foreground : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { colleague = id }
    }
}
