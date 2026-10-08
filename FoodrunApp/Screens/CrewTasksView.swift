import SwiftUI

// Tasks tab: what this crew member has to do, per day, across their events —
// the prep checklist and stock count of each event (as list cards that open
// the shift on Taken) and the operator's tasks (HQ → Activity → Crew-app).
// Ticks and values go straight back to HQ; tapping the event name opens the
// shift.

public struct CrewTasksView: View {
    @Environment(TabRouter.self) private var router
    @Environment(CrewTasksStore.self) private var store
    @Environment(ScheduleStore.self) private var schedule
    @State private var openDish: CrewDish?
    @State private var answering: CrewTaskOccurrence?

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
                if store.occurrences.isEmpty && store.lists.isEmpty {
                    if store.isLoading && !store.hasLoaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        emptyState
                    }
                }
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
                                action: {
                                    router.tasksPath.append(.event(activityId: entry.activity.id,
                                                                   date: SchemaDates.date(entry.date) ?? Date()))
                                }
                            )
                        }
                        ForEach(group.items) { occ in
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
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable { await store.load() }
        .task { await store.load() }
        .sheet(item: $openDish) { dish in CrewDishSheet(dish: dish) }
        .sheet(item: $answering) { occ in answerSheet(for: occ) }
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
