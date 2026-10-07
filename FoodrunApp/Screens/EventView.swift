import SwiftUI

// One event for this crew member: the parts of the script the operator
// switched on for them in HQ (Activity → Crew-app) plus the tasks they were
// given. Pushed from Shift detail ("Briefing & tasks") and from the Tasks tab.
//
// Sections: Tasks (always) · Briefing (run-of-show + a personal note) ·
// Dishes (recipe + ingredients) · Prep (read-only packing list as ticked in
// the prep portal) · Stock (count products; the count goes to HQ, the stock
// itself isn't changed).

public struct EventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store: EventStore
    @State private var section: CrewEventSection = .tasks
    @State private var day: String
    @State private var openDish: CrewDish?
    @State private var answering: CrewTask?
    @State private var counting: CrewStockProduct?

    public init(activityId: UUID, date: Date) {
        _store = State(initialValue: EventStore(activityId: activityId))
        _day = State(initialValue: SchemaDates.string(date))
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let event = store.event {
                    titleBlock(event)
                    if event.my_days.count > 1 { dayPicker(event) }
                    sectionPicker(event)
                    if let error = store.lastError { errorLine(error) }
                    if event.activity.is_closed {
                        infoLine(FRLanguage.string("crew.event.closed"))
                    }
                    content(event)
                } else if store.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if let error = store.lastError {
                    errorLine(error)
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .refreshable { await store.load() }
        .task {
            await store.load()
            settleDayAndSection()
        }
        .sheet(item: $openDish) { dish in CrewDishSheet(dish: dish) }
        .sheet(item: $answering) { task in answerSheet(for: task) }
        .sheet(item: $counting) { product in countSheet(for: product) }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack {
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
            Spacer()
        }
    }

    private func titleBlock(_ event: CrewEvent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(Color.foodrunData(hex: event.activity.color)).frame(width: 8, height: 8)
                Text(verbatim: event.activity.food_truck ?? event.activity.name).frText(FRType.eyebrow)
            }
            Text(verbatim: event.activity.name).font(.system(size: 26, weight: .bold)).tracking(-0.6)
            if let location = event.activity.location {
                Text(verbatim: location).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    private func dayPicker(_ event: CrewEvent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(event.my_days, id: \.self) { d in
                    pill(CrewFormat.day(d), active: d == day) { day = d }
                }
            }
        }
    }

    private func sectionPicker(_ event: CrewEvent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CrewEventSection.allCases.filter { event.has($0) }) { s in
                    pill(label(for: s), active: s == section) {
                        withAnimation(FRAnimation.subtle) { section = s }
                    }
                }
            }
        }
    }

    private func pill(_ text: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { action(); FRHaptic.light.fire() }) {
            Text(verbatim: text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(Capsule().fill(active ? Color.foodrun.foreground : Color.foodrun.card))
        }
        .buttonStyle(.plain)
    }

    private func label(for section: CrewEventSection) -> String {
        switch section {
        case .tasks: return FRLanguage.string("crew.section.tasks")
        case .briefing: return FRLanguage.string("crew.section.briefing")
        case .dishes: return FRLanguage.string("crew.section.dishes")
        case .prep: return FRLanguage.string("crew.section.prep")
        case .stock: return FRLanguage.string("crew.section.stock")
        }
    }

    private func errorLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text(verbatim: text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.foodrun.subject.destructive)
    }

    private func infoLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock")
            Text(verbatim: text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
    }

    private func emptyLine(_ key: String) -> some View {
        Text(verbatim: FRLanguage.string(key))
            .frText(FRType.rowSubtitle)
            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    /// Open on the shift's own day when it's one of my days, else the first
    /// upcoming one; fall back to Tasks when the chosen section isn't on.
    private func settleDayAndSection() {
        guard let event = store.event else { return }
        if !event.my_days.contains(day) {
            let today = SchemaDates.string(Date())
            day = event.my_days.first { $0 >= today } ?? event.my_days.first ?? day
        }
        if !event.has(section) { section = .tasks }
    }

    // MARK: - Sections

    @ViewBuilder
    private func content(_ event: CrewEvent) -> some View {
        switch section {
        case .tasks: tasksSection(event)
        case .briefing: briefingSection(event.briefing)
        case .dishes: dishesSection(event.dishes ?? [])
        case .prep: prepSection(event.prep)
        case .stock: stockSection(event)
        }
    }

    private func tasksSection(_ event: CrewEvent) -> some View {
        let list = store.tasks(on: day)
        return VStack(spacing: 10) {
            if list.isEmpty { emptyLine("crew.tasks.none") }
            ForEach(list) { task in
                let response = store.response(for: task, on: day)
                CrewTaskRow(
                    task: task,
                    response: response,
                    isSaving: store.saving.contains(task.id),
                    isClosed: event.activity.is_closed,
                    onToggle: {
                        Task {
                            let ok = await store.answer(task, on: day, done: !(response?.done ?? false))
                            if ok { FRHaptic.success.fire() } else { FRHaptic.error.fire() }
                        }
                    },
                    onAnswer: { answering = task },
                    onOpenDish: { openDish = $0 }
                )
            }
        }
    }

    @ViewBuilder
    private func briefingSection(_ briefing: CrewBriefing?) -> some View {
        let notes = (briefing?.notes ?? []).filter { $0.date == day }
        let headings = briefing?.headings ?? []
        VStack(alignment: .leading, spacing: 12) {
            if notes.isEmpty && headings.isEmpty { emptyLine("crew.briefing.none") }
            ForEach(notes, id: \.self) { note in
                VStack(alignment: .leading, spacing: 6) {
                    Text("crew.briefing.forYou").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.subject.agentNoteBlue)
                    if let start = note.start_time {
                        Text(verbatim: [start, note.end_time].compactMap { $0 }.joined(separator: " – "))
                            .frText(FRType.rowTitle).monospacedDigit()
                    }
                    if let comment = note.comment {
                        Text(verbatim: comment).frText(FRType.body)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.agentNoteField))
            }
            ForEach(headings) { heading in
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: heading.name).frText(FRType.rowTitle)
                    if let content = heading.content, !content.isEmpty {
                        Text(verbatim: content).frText(FRType.body).foregroundStyle(Color.foodrun.bodySoft)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                .frNeu(.raised)
            }
        }
    }

    private func dishesSection(_ dishes: [CrewDish]) -> some View {
        VStack(spacing: 10) {
            if dishes.isEmpty { emptyLine("crew.dishes.none") }
            ForEach(dishes) { dish in
                Button { openDish = dish } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 15, weight: .medium))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.foodrun.neuTrack))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: dish.name).frText(FRType.rowTitle)
                            Text(verbatim: String(format: FRLanguage.string("crew.dish.ingredientCount %lld"), dish.ingredients.count))
                                .frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    .foregroundStyle(Color.foodrun.foreground)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                    .frNeu(.raised)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func prepSection(_ prep: CrewPrep?) -> some View {
        let items = prep?.items ?? []
        let order = ["ingredients", "equipment", "rentals", "addons"]
        VStack(alignment: .leading, spacing: 14) {
            if items.isEmpty { emptyLine("crew.prep.none") }
            ForEach(order, id: \.self) { group in
                let rows = items.filter { $0.section == group }
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: FRLanguage.string("crew.prep.group.\(group)")).frText(FRType.sectionHeader)
                        VStack(spacing: 0) {
                            ForEach(rows) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(item.checked ? Color.foodrun.subject.positive : Color.foodrun.mutedForegroundSoft)
                                    Text(verbatim: item.name).frText(FRType.rowTitle)
                                    Spacer()
                                    Text(verbatim: CrewFormat.quantity(item.quantity, item.unit))
                                        .frText(FRType.rowSubtitle).monospacedDigit()
                                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                                .padding(.vertical, 10)
                                if item.id != rows.last?.id {
                                    Rectangle().fill(Color.foodrun.border).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                        .frNeu(.raised)
                    }
                }
            }
            if !items.isEmpty {
                Text("crew.prep.readOnly")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    private func stockSection(_ event: CrewEvent) -> some View {
        let products = event.stock?.products ?? []
        return VStack(alignment: .leading, spacing: 10) {
            if products.isEmpty { emptyLine("crew.stock.none") }
            ForEach(products) { product in
                let mine = store.myCount(productId: product.product_id, on: day)
                Button { counting = product } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: product.name).frText(FRType.rowTitle)
                            Text(verbatim: String(format: FRLanguage.string("crew.stock.planned %@"),
                                                  CrewFormat.quantity(product.planned_quantity, product.units.first)))
                                .frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        }
                        Spacer()
                        Group {
                            if store.saving.contains(product.product_id) {
                                ProgressView()
                            } else if let mine {
                                Text(verbatim: CrewFormat.quantity(mine.quantity, product.units[safe: mine.unit_level]))
                                    .monospacedDigit()
                            } else {
                                Text("crew.stock.count")
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(mine != nil ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Capsule().fill(mine != nil ? Color.foodrun.foreground : Color.foodrun.neuTrack))
                    }
                    .foregroundStyle(Color.foodrun.foreground)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                    .frNeu(.raised)
                }
                .buttonStyle(.plain)
                .disabled(event.activity.is_closed)
            }
            if !products.isEmpty {
                Text("crew.stock.footnote")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    // MARK: - Sheets

    private func answerSheet(for task: CrewTask) -> some View {
        let current = store.response(for: task, on: day)
        return CrewAnswerSheet(
            title: task.title,
            prompt: task.instructions,
            kind: task.kind,
            units: task.unit.map { [$0] } ?? [],
            initialNumber: current?.value_number,
            initialText: current?.value_text,
            initialUnitLevel: 0,
            canClear: current != nil,
            onSave: { number, text, _ in
                await store.answer(task, on: day, done: true, number: number, text: text)
            },
            onClear: { await store.answer(task, on: day, done: false) }
        )
    }

    private func countSheet(for product: CrewStockProduct) -> some View {
        let mine = store.myCount(productId: product.product_id, on: day)
        return CrewAnswerSheet(
            title: product.name,
            prompt: String(format: FRLanguage.string("crew.stock.prompt %@"), CrewFormat.day(day)),
            kind: .count,
            units: product.units,
            initialNumber: mine?.quantity,
            initialText: nil,
            initialUnitLevel: mine?.unit_level ?? 0,
            canClear: mine != nil,
            onSave: { number, _, level in
                await store.count(productId: product.product_id, on: day, quantity: number, unitLevel: level)
            },
            onClear: { await store.count(productId: product.product_id, on: day, quantity: nil, unitLevel: 0) }
        )
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
