import SwiftUI

// A colleague's shift, opened from the Rooster view: who works when, plus the event's
// Draaiboek and Setup (get_my_event) — view only. No tasks, no clocking, no pinning;
// the one action is asking to take the shift over (TakeoverSheet).

struct ColleagueShiftView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScheduleStore.self) private var schedule

    let shift: TeamShift

    @State private var store: EventStore
    @State private var tab: ShiftTab = .briefing
    @State private var openDish: CrewDish?
    @State private var asking = false

    init(shift: TeamShift) {
        self.shift = shift
        _store = State(initialValue: EventStore(activityId: shift.activity.id))
    }

    private var isPast: Bool { shift.day < SchemaDates.string(schedule.today) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                personCard
                content
                if !isPast && AppConfig.Features.shiftSwaps { askButton }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 8)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await store.load() }
        .task { await store.load() }
        .sheet(item: $openDish) { dish in CrewDishSheet(dish: dish) }
        .sheet(isPresented: $asking) {
            TakeoverSheet(shift: shift)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: store.event?.activity.name ?? shift.activity.name)
                    .font(.system(size: 20, weight: .bold)).tracking(-0.4)
                    .lineLimit(2)
                let sub = [schedule.worksForSeveral ? shift.employer : nil,
                           shift.activity.food_truck,
                           store.event?.activity.location].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
                if !sub.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color.foodrunData(hex: shift.activity.color)).frame(width: 7, height: 7)
                        Text(verbatim: sub).lineLimit(1)
                    }
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
    }

    /// Who and when — plain text, nothing to tap.
    private var personCard: some View {
        HStack(spacing: 14) {
            Text(verbatim: initials)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Color.foodrunData(hex: shift.color ?? shift.activity.color)))
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: String(format: FRLanguage.string("colleague.title %@"), shift.name))
                    .frText(FRType.rowTitle)
                Text(verbatim: "\(PeopleFormat.day(shift.day)) · \(PeopleFormat.window(shift.window))")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        if let event = store.event {
            FRSegmentedPills([ShiftTab.briefing, .setup], selection: $tab) { t in
                t == .briefing ? "shift.tab.briefing" : "shift.tab.setup"
            }
            switch tab {
            case .setup:
                ShiftSetupContent(briefing: event.briefing)
            default:
                ShiftBriefingContent(store: store, event: event, day: shift.day,
                                     onOpenDish: { openDish = $0 }, readOnly: true)
            }
        } else if store.isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        } else {
            // Not working this event, or the employer keeps the run sheet to its crew.
            CrewBriefingEmpty(key: "colleague.briefingUnavailable")
        }
    }

    @ViewBuilder
    private var askButton: some View {
        Button { asking = true } label: {
            Text(shift.ask == nil ? "colleague.askTakeover" : "colleague.asked")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 50)
                .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var initials: String {
        shift.name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}
