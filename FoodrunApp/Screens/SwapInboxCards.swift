import SwiftUI

// Ruilen in the Inbox: what waits for my answer (a colleague asks for my shift, a colleague
// offers me theirs) and the asks I sent that are still running. Answering here is the same as
// on the swap board (Me → Ruilen); the board keeps the full history.

public struct SwapInboxCards: View {
    @Environment(SwapStore.self) private var swaps
    @Environment(ScheduleStore.self) private var schedule

    public init() {}

    /// Shifts I'm taking that haven't been decided yet: my asks, an offer I accepted and open
    /// places I asked for. Without these an accepted offer simply vanished from the Inbox.
    private static func runningAsks(_ swaps: SwapStore) -> [MySwapRequest] {
        swaps.board.mine.filter { $0.role == "taker" && ($0.status == "open" || $0.status == "accepted") }
    }

    private var myRunningAsks: [MySwapRequest] { Self.runningAsks(swaps) }

    /// Whether the Inbox shows any swap card (the Inbox hides its empty text then).
    public static func hasCards(_ swaps: SwapStore) -> Bool {
        !swaps.board.asked.isEmpty || !swaps.board.offered.isEmpty || !runningAsks(swaps).isEmpty
    }

    public var body: some View {
        if Self.hasCards(swaps) {
            VStack(alignment: .leading, spacing: 8) {
                Text("swaps.title").frText(FRType.sectionHeader)
                if let error = swaps.lastError {
                    Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
                }
                ForEach(swaps.board.asked) { askRow($0) }
                ForEach(swaps.board.offered) { offerRow($0) }
                ForEach(myRunningAsks) { sentRow($0) }
            }
        }
    }

    // A colleague wants my shift: give it or keep it.
    private func askRow(_ ask: SwapAsk) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                kicker
                shiftLine(ask.activity, ask.day, ask.window, employer: ask.employer)
                Text("swaps.asked \(ask.taker_name)").frText(FRType.rowSubtitle)
                note(ask.note)
                HStack(spacing: 8) {
                    pill("swaps.give") {
                        Task { if await swaps.answer(ask, give: true) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } }
                    }
                    pill("swaps.keep", filled: false) { Task { _ = await swaps.answer(ask, give: false) } }
                }
            }
        }
    }

    // A colleague offers me (or everyone) their shift.
    private func offerRow(_ offer: SwapOffer) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                kicker
                shiftLine(offer.activity, offer.day, offer.window, employer: offer.employer)
                Group {
                    if offer.to_me {
                        Text("swaps.offer.toMe \(offer.from_name)")
                    } else {
                        Text("swaps.offer.toAll \(offer.from_name)")
                    }
                }
                .frText(FRType.rowSubtitle)
                note(offer.note)
                HStack(spacing: 8) {
                    pill("swaps.takeOver") {
                        Task { if await swaps.respond(offer, accept: true) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } }
                    }
                    if offer.to_me {
                        pill("swaps.decline", filled: false) { Task { _ = await swaps.respond(offer, accept: false) } }
                    }
                }
            }
        }
    }

    // An ask I sent: where it stands, and take it back.
    private func sentRow(_ r: MySwapRequest) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                kicker
                shiftLine(r.activity, r.day, r.window, employer: r.employer)
                Group {
                    if r.kind != "ask" {
                        // An offer I took or an open place I asked for: only the planner is left.
                        Text(LocalizedStringKey(r.status == "accepted" ? "swaps.status.accepted" : "swaps.status.open"))
                    } else if r.status == "accepted" {
                        Text("takeover.status.accepted \(r.from_name ?? "")")
                    } else {
                        Text("takeover.status.open \(r.from_name ?? "")")
                    }
                }
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.subject.warning)
                pill("swaps.withdraw", filled: false) { Task { _ = await swaps.withdraw(requestId: r.id) } }
            }
        }
    }

    private var kicker: some View {
        Text("inbox.swap").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.subject.swapOpenInk)
    }

    @ViewBuilder
    private func note(_ text: String?) -> some View {
        if let text, !text.isEmpty {
            Text(verbatim: "“\(text)”").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
            .frNeu(.raised)
    }

    private func shiftLine(_ activity: SwapActivity, _ day: String, _ window: DBDayTimes, employer: String?) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color.foodrunData(hex: activity.color)).frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: activity.title).frText(FRType.rowTitle).lineLimit(1)
                Text(verbatim: subtitle(day, window, employer))
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    private func subtitle(_ day: String, _ window: DBDayTimes, _ employer: String?) -> String {
        let base = "\(PeopleFormat.day(day)) · \(PeopleFormat.window(window))"
        guard schedule.worksForSeveral, let employer, !employer.isEmpty else { return base }
        return "\(base) · \(employer)"
    }

    private func pill(_ label: LocalizedStringKey, filled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filled ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                .padding(.horizontal, 14).frame(minHeight: 36)
                .background(Capsule().fill(filled ? Color.foodrun.foreground : Color.clear))
                .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: filled ? 0 : 1))
        }
        .buttonStyle(.plain)
        .disabled(swaps.busy)
    }
}
