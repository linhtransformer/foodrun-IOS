import SwiftUI

// Tap a colleague's shift on the Rooster tab: ask to take it over (take over only — nothing is
// given back). request_shift_takeover tells the colleague; they give it or keep it in their
// Inbox, then the planner approves in HQ unless the employer lets swaps happen at once.

public struct TakeoverSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwapStore.self) private var swaps
    @Environment(ScheduleStore.self) private var schedule

    let shift: TeamShift
    @State private var note = ""

    public init(shift: TeamShift) {
        self.shift = shift
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("takeover.title \(shift.name)").frText(FRType.sectionHeader)
            Text(verbatim: context)
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)

            if let ask = shift.ask {
                // Already asked: say where it stands, and let me take it back.
                Group {
                    if ask.status == "accepted" {
                        Text("takeover.status.accepted \(shift.name)")
                    } else {
                        Text("takeover.status.open \(shift.name)")
                    }
                }
                .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.subject.warning)
                errorLine
                Button {
                    Task {
                        if await swaps.withdraw(requestId: ask.id) { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire() }
                    }
                } label: {
                    Text("swaps.withdraw")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(swaps.busy)
            } else {
                Text("takeover.body \(shift.name)")
                    .frText(FRType.rowSubtitle)

                TextField(text: $note, prompt: Text("swap.note.placeholder")) { Text("swap.note.placeholder") }
                    .font(.system(size: 15))
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))

                errorLine

                Button {
                    Task {
                        if await swaps.askTakeover(shift, note: note.trimmingCharacters(in: .whitespacesAndNewlines)) {
                            FRHaptic.success.fire()
                            dismiss()
                        } else {
                            FRHaptic.error.fire()
                        }
                    }
                } label: {
                    Text("takeover.send")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.foodrun.backgroundInverseInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(Color.foodrun.foreground))
                        .frCTAShadow()
                }
                .buttonStyle(.plain)
                .disabled(swaps.busy)
            }
        }
        .padding(20)
        .background(Color.foodrun.background.ignoresSafeArea(edges: .bottom))
        .onAppear { swaps.lastError = nil }
    }

    @ViewBuilder
    private var errorLine: some View {
        if let error = swaps.lastError {
            Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
        }
    }

    /// "Truck Mees · za 24 okt · 12:00 – 22:00", plus the employer when the worker has several.
    private var context: String {
        var parts = [shift.activity.title, PeopleFormat.day(shift.day), PeopleFormat.window(shift.window)]
        if schedule.worksForSeveral, let employer = shift.employer, !employer.isEmpty { parts.append(employer) }
        return parts.joined(separator: " · ")
    }
}
