import SwiftUI

// Ruilen (HQ part 8, decision 0088): what colleagues offer me, open shifts I can ask for, my
// coming shifts (offer one) and what happened to my requests. The planner approves in HQ
// (Rooster → Ruilverzoeken) unless the employer lets swaps happen at once.

enum PeopleFormat {
    static func day(_ iso: String) -> String {
        guard let d = SchemaDates.date(iso) else { return iso }
        let f = DateFormatter(); f.locale = FRLanguage.locale; f.dateFormat = "EEE d MMM"
        return f.string(from: d)
    }

    static func window(_ w: DBDayTimes) -> String {
        guard let s = w.startTime else { return FRLanguage.string("shift.timeTBD") }
        return "\(s.prefix(5)) – \((w.endTime ?? "").prefix(5))"
    }
}

public struct SwapsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(SwapStore.self) private var swaps
    @Environment(ScheduleStore.self) private var schedule
    @State private var offering: SwapShift?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if let error = swaps.lastError {
                    Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
                }
                if !swaps.board.asked.isEmpty {
                    section("swaps.section.asked") { ForEach(swaps.board.asked) { askRow($0) } }
                }
                if !swaps.board.offered.isEmpty {
                    section("swaps.section.offered") { ForEach(swaps.board.offered) { offerRow($0) } }
                }
                if !swaps.board.open_shifts.isEmpty {
                    section("swaps.section.open") { ForEach(swaps.board.open_shifts) { openRow($0) } }
                }
                section("swaps.section.mine") {
                    if swaps.board.my_shifts.isEmpty {
                        Text("swaps.mine.empty").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    ForEach(swaps.board.my_shifts) { myShiftRow($0) }
                }
                // Everything I take over (offers I accepted, asks, open places) plus finished requests;
                // my own running offers already show on their shift above.
                let history = swaps.board.mine.filter { $0.role == "taker" || ($0.status != "open" && $0.status != "accepted") }
                if !history.isEmpty {
                    section("swaps.section.history") { ForEach(history) { historyRow($0) } }
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await swaps.load() }
        .task { await swaps.load() }
        .sheet(item: $offering) { shift in
            SwapOfferSheet(shift: shift)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            Text("swaps.title").frText(FRType.screenTitle)
            Text("swaps.subtitle").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).frText(FRType.sectionHeader)
            VStack(spacing: 8) { content() }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
            .frNeu(.raised)
    }

    private func shiftLine(_ activity: SwapActivity, _ day: String, _ window: DBDayTimes, employer: String? = nil) -> some View {
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

    /// "za 18 okt · 09:30 – 18:00", plus " · Vietnamama" when the worker has several employers.
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

    private func offerRow(_ offer: SwapOffer) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                shiftLine(offer.activity, offer.day, offer.window, employer: offer.employer)
                Group {
                    if offer.to_me {
                        Text("swaps.offer.toMe \(offer.from_name)")
                    } else {
                        Text("swaps.offer.toAll \(offer.from_name)")
                    }
                }
                .frText(FRType.rowSubtitle)
                if let note = offer.note, !note.isEmpty {
                    Text(verbatim: "“\(note)”").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                HStack(spacing: 8) {
                    pill("swaps.takeOver") { Task { if await swaps.respond(offer, accept: true) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } } }
                    if offer.to_me {
                        pill("swaps.decline", filled: false) { Task { _ = await swaps.respond(offer, accept: false) } }
                    }
                }
            }
        }
    }

    private func askRow(_ ask: SwapAsk) -> some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                shiftLine(ask.activity, ask.day, ask.window, employer: ask.employer)
                Text("swaps.asked \(ask.taker_name)").frText(FRType.rowSubtitle)
                if let note = ask.note, !note.isEmpty {
                    Text(verbatim: "“\(note)”").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                HStack(spacing: 8) {
                    pill("swaps.give") { Task { if await swaps.answer(ask, give: true) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } } }
                    pill("swaps.keep", filled: false) { Task { _ = await swaps.answer(ask, give: false) } }
                }
            }
        }
    }

    private func openRow(_ open: OpenShift) -> some View {
        card {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    shiftLine(open.activity, open.day, open.window, employer: open.employer)
                    Text("swaps.openPlaces \(open.open)").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.positive)
                }
                Spacer(minLength: 8)
                if open.requested {
                    Text("swaps.requested").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.subject.warning)
                } else {
                    pill("swaps.iWantThis") { Task { if await swaps.pickUp(open) { FRHaptic.success.fire(); await schedule.load() } else { FRHaptic.error.fire() } } }
                }
            }
        }
    }

    private func myShiftRow(_ shift: SwapShift) -> some View {
        card {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    shiftLine(shift.activity, shift.day, shift.window, employer: shift.employer)
                    if let r = shift.request {
                        Group {
                            if r.status == "accepted" {
                                Text("swaps.mine.accepted \(r.taker_name ?? "")")
                            } else if let to = r.to_name {
                                Text("swaps.mine.offeredTo \(to)")
                            } else {
                                Text("swaps.mine.offeredAll")
                            }
                        }
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.subject.warning)
                    }
                }
                Spacer(minLength: 8)
                if let r = shift.request {
                    pill("swaps.withdraw", filled: false) { Task { _ = await swaps.withdraw(requestId: r.id) } }
                } else {
                    pill("swaps.offer", filled: false) { offering = shift }
                }
            }
        }
    }

    private func historyRow(_ r: MySwapRequest) -> some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                shiftLine(r.activity, r.day, r.window, employer: r.employer)
                HStack(spacing: 6) {
                    Text(verbatim: historyLine(r))
                        .frText(FRType.rowSubtitle)
                    Spacer()
                    Text(LocalizedStringKey("swaps.status.\(r.status)"))
                        .frText(FRType.fieldLabel)
                        .foregroundStyle(statusColor(r.status))
                }
                if let note = r.manager_note, !note.isEmpty {
                    Text(verbatim: "“\(note)”").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                if (r.kind == "pickup" || (r.kind == "ask" && r.role == "taker")) && (r.status == "open" || r.status == "accepted") {
                    pill("swaps.withdraw", filled: false) { Task { _ = await swaps.withdraw(requestId: r.id) } }
                }
            }
        }
    }

    private func historyLine(_ r: MySwapRequest) -> String {
        guard r.kind != "pickup" else { return FRLanguage.string("swaps.openShift") }
        let who = r.taker_name ?? r.to_name ?? FRLanguage.string("swaps.everyone")
        return "\(r.from_name ?? "") → \(who)"
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "approved": return Color.foodrun.subject.positive
        case "declined": return Color.foodrun.subject.destructive
        case "open", "accepted": return Color.foodrun.subject.warning
        default: return Color.foodrun.mutedForegroundSoft
        }
    }
}
