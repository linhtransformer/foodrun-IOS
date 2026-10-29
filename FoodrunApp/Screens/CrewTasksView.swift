import SwiftUI

// Tasks tab: what this crew member has to do, per day, across their events —
// the prep checklist and stock count of each event (list cards that open the
// list itself, right here) and the operator's tasks (HQ → Activity → Crew-app).
// Ticks and values go straight back to HQ; tapping the event name opens the
// shift.

public struct CrewTasksView: View {
    @Environment(TabRouter.self) private var router
    @Environment(CrewTasksStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @State private var openDish: CrewDish?
    @State private var answering: CrewTaskOccurrence?
    @State private var answeringGoal: CrewWeekGoal?
    /// The prep list or stock count opened from its card.
    @State private var openList: CrewListEntry?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("crew.tasksTab.title").font(.system(size: 28, weight: .bold)).tracking(-0.8)
                if let error = store.lastError {
                    Text(verbatim: error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                }
                if store.occurrences.isEmpty && store.lists.isEmpty && store.weekGoals.isEmpty {
                    if store.isLoading && !store.hasLoaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        emptyState
                    }
                }
                if !store.weekGoals.isEmpty { weekSection }
                ForEach(store.days) { group in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(verbatim: dayTitle(group.day)).frText(FRType.sectionHeader)
                            Spacer()
                            let open = store.openCount(on: group.day)
                            if open > 0 {
                                Text(verbatim: String(format: FRLanguage.string("crew.tasksTab.open %lld"), open))
                                    .frText(FRType.rowSubtitle)
                                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                        }
                        ForEach(group.lists) { entry in
                            CrewChecklistTaskCard(
                                symbol: entry.kind == "prep" ? "shippingbox" : "number",
                                kindKey: entry.kind == "prep" ? "tasks.prep.kind" : "tasks.stock.kind",
                                title: FRLanguage.string(entry.kind == "prep" ? "tasks.prep.title" : "tasks.stock.title"),
                                detail: listDetail(entry),
                                done: entry.done,
                                total: entry.total,
                                action: { openList = entry }
                            )
                        }
                        ForEach(CrewTaskGroup.build(group.items, task: { $0.task })) { checklist in
                          if let title = checklist.title {
                              CrewChecklistHeader(title: title,
                                                  done: checklist.items.filter { $0.response?.done ?? false }.count,
                                                  total: checklist.items.count)
                          }
                          ForEach(checklist.items) { occ in
                            CrewTaskRow(
                                task: occ.task,
                                response: occ.response,
                                eventName: occ.activity.name,
                                isSaving: store.saving.contains(occ.id),
                                isClosed: occ.activity.is_closed,
                                onToggle: {
                                    Task {
                                        let ok = await store.answer(occ, done: !(occ.response?.done ?? false))
                                        if ok { FRHaptic.success.fire() } else { FRHaptic.error.fire() }
                                    }
                                },
                                onAnswer: { answering = occ },
                                onOpenDish: { openDish = $0 },
                                onOpenEvent: {
                                    router.tasksPath.append(.event(activityId: occ.activity.id,
                                                                   date: SchemaDates.date(occ.date) ?? Date()))
                                }
                            )
                          }
                        }
                    }
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable { await store.load() }
        .task { await store.load() }
        .sheet(item: $openDish) { dish in CrewDishSheet(dish: dish) }
        .sheet(item: $answering) { occ in answerSheet(for: occ) }
        .sheet(item: $answeringGoal) { goal in goalSheet(for: goal) }
        // Back on the list: refresh so the card shows the new progress.
        .sheet(item: $openList, onDismiss: { Task { await store.load() } }) { entry in
            CrewListLoaderSheet(entry: entry)
        }
    }

    /// Goals for this week, not tied to a shift (HQ → Taken → Weekdoelen).
    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("crew.tasksTab.week").frText(FRType.sectionHeader)
                Spacer()
                if store.openWeekGoals > 0 {
                    Text(verbatim: String(format: FRLanguage.string("crew.tasksTab.open %lld"), store.openWeekGoals))
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            ForEach(CrewTaskGroup.build(store.weekGoals, task: { $0.task })) { checklist in
                if let title = checklist.title {
                    CrewChecklistHeader(title: title,
                                        done: checklist.items.filter { $0.response?.done ?? false }.count,
                                        total: checklist.items.count)
                }
                ForEach(checklist.items) { goal in
                    CrewTaskRow(
                        task: goal.task,
                        response: goal.response,
                        isSaving: store.saving.contains(goal.id),
                        isClosed: false,
                        onToggle: {
                            Task {
                                let ok = await store.answer(goal, done: !(goal.response?.done ?? false))
                                if ok { FRHaptic.success.fire() } else { FRHaptic.error.fire() }
                            }
                        },
                        onAnswer: { answeringGoal = goal },
                        onOpenDish: { openDish = $0 }
                    )
                }
            }
        }
    }

    private func goalSheet(for goal: CrewWeekGoal) -> some View {
        CrewAnswerSheet(
            title: goal.task.title,
            prompt: goal.task.instructions,
            kind: goal.task.kind,
            units: goal.task.unit.map { [$0] } ?? [],
            initialNumber: goal.response?.value_number,
            initialText: goal.response?.value_text,
            initialUnitLevel: 0,
            canClear: goal.response != nil,
            onSave: { number, text, _ in await store.answer(goal, done: true, number: number, text: text) },
            onClear: { await store.answer(goal, done: false) }
        )
    }

    @ViewBuilder
    private func answerSheet(for occ: CrewTaskOccurrence) -> some View {
        // This person's employee row at the event's operator (photo path).
        let employeeId = schedule.activities.first(where: { $0.id == occ.activity.id })
            .flatMap { schedule.employee(for: $0) }?.id
        if occ.task.kind == .photo {
            CrewPhotoSheet(
                title: occ.task.title,
                prompt: occ.task.instructions,
                existingPath: occ.response?.photo_path,
                onSave: { jpeg in
                    guard let employeeId else { return false }
                    return await store.answerPhoto(occ, employeeId: employeeId, jpeg: jpeg)
                },
                onClear: { await store.answer(occ, done: false) }
            )
        } else {
            CrewAnswerSheet(
                title: occ.task.title,
                prompt: occ.task.instructions,
                kind: occ.task.kind,
                units: occ.task.unit.map { [$0] } ?? [],
                initialNumber: occ.response?.value_number,
                initialText: occ.response?.value_text,
                initialUnitLevel: 0,
                canClear: occ.response != nil,
                onSave: { number, text, _ in await store.answer(occ, done: true, number: number, text: text) },
                onClear: { await store.answer(occ, done: false) }
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checklist")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text("crew.tasksTab.empty")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 50)
    }

    /// "Stadsfestival · 2 van 4 ingepakt".
    private func listDetail(_ entry: CrewListEntry) -> String {
        let progress = entry.kind == "prep"
            ? String(format: FRLanguage.string("crew.prep.progress %lld %lld"), entry.done, entry.total)
            : String(format: FRLanguage.string("tasks.stock.progress %lld %lld"), entry.done, entry.total)
        return "\(entry.activity.name) · \(progress)"
    }

    private func dayTitle(_ key: String) -> String {
        let today = SchemaDates.string(Date())
        let tomorrow = SchemaDates.string(Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        if key == today { return FRLanguage.string("crew.tasksTab.today") }
        if key == tomorrow { return FRLanguage.string("crew.tasksTab.tomorrow") }
        return CrewFormat.day(key)
    }
}

/// Loads the event behind a prep / stock card, then shows the same list as the shift's
/// Taken tab — without taking the crew member to the shift first.
private struct CrewListLoaderSheet: View {
    let entry: CrewListEntry
    @Environment(\.dismiss) private var dismiss
    @State private var event: EventStore

    init(entry: CrewListEntry) {
        self.entry = entry
        _event = State(initialValue: EventStore(activityId: entry.activity.id))
    }

    var body: some View {
        Group {
            if event.event != nil {
                if entry.kind == "prep" {
                    CrewPrepListSheet(store: event)
                } else {
                    CrewStockListSheet(store: event, day: entry.date)
                }
            } else if let error = event.lastError {
                VStack(alignment: .leading, spacing: 14) {
                    CrewSheetHeader(title: FRLanguage.string(entry.kind == "prep" ? "tasks.prep.title" : "tasks.stock.title")) { dismiss() }
                    Text(verbatim: error).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.subject.destructive)
                    Spacer(minLength: 0)
                }
                .padding(20)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .task { await event.load() }
    }
}
