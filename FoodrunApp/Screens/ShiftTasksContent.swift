import SwiftUI

// The shift's Taken tab (HQ decision 0038): everything this crew member has to
// do on the selected day — the prep checklist and the stock count as task
// cards (each opens its own list), then the operator's tasks. The briefing
// (Draaiboek/Setup) never holds an input; this tab does.

struct ShiftTasksContent: View {
    let store: EventStore
    let event: CrewEvent
    let day: String
    let onOpenDish: (CrewDish) -> Void
    let onAnswer: (CrewTask) -> Void
    let onOpenPrep: () -> Void
    let onOpenStock: () -> Void

    var body: some View {
        let list = store.tasks(on: day)
        let prepItems = event.prep?.items ?? []
        let products = event.stock?.products ?? []
        VStack(spacing: 10) {
            if !prepItems.isEmpty {
                CrewChecklistTaskCard(
                    symbol: "shippingbox",
                    kindKey: "tasks.prep.kind",
                    title: FRLanguage.string("tasks.prep.title"),
                    detail: String(format: FRLanguage.string("crew.prep.progress %lld %lld"),
                                   prepItems.filter(\.checked).count, prepItems.count),
                    done: prepItems.filter(\.checked).count,
                    total: prepItems.count,
                    action: onOpenPrep
                )
            }
            if !products.isEmpty {
                let counted = products.filter { store.myCount(productId: $0.product_id, on: day) != nil }.count
                CrewChecklistTaskCard(
                    symbol: "number",
                    kindKey: "tasks.stock.kind",
                    title: FRLanguage.string("tasks.stock.title"),
                    detail: String(format: FRLanguage.string("tasks.stock.progress %lld %lld"), counted, products.count),
                    done: counted,
                    total: products.count,
                    action: onOpenStock
                )
            }
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
                    onAnswer: { onAnswer(task) },
                    onOpenDish: onOpenDish
                )
            }
            if list.isEmpty && prepItems.isEmpty && products.isEmpty {
                CrewBriefingEmpty(key: "crew.tasks.none")
            }
        }
    }
}

/// A list-type task (prep checklist, stock count) in the same card layout as
/// the operator's tasks: type + status on top, progress, one action.
struct CrewChecklistTaskCard: View {
    let symbol: String
    let kindKey: String
    let title: String
    let detail: String
    let done: Int
    let total: Int
    let action: () -> Void

    private var finished: Bool { total > 0 && done >= total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(finished ? Color.foodrun.subject.positive : Color.foodrun.foreground)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(finished ? Color.foodrun.subject.positive.opacity(0.14) : Color.foodrun.neuTrack)
                    )
                Text(LocalizedStringKey(kindKey))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Spacer(minLength: 8)
                Text(LocalizedStringKey(finished ? "crew.status.done" : "crew.status.open"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(finished ? Color.foodrun.subject.positive : Color.foodrun.mutedForegroundSoft)
            }
            .accessibilityElement(children: .combine)
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: title).frText(FRType.rowTitle)
                Text(verbatim: detail).frText(FRType.rowSubtitle).monospacedDigit()
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .tint(Color.foodrun.subject.positive)
            }
            Button(action: action) {
                HStack(spacing: 6) {
                    Image(systemName: finished ? "checkmark" : "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                    Text(LocalizedStringKey(finished ? "tasks.list.view" : "tasks.list.open"))
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(finished ? Color.foodrun.subject.positive : Color.foodrun.foreground)
                .frame(maxWidth: .infinity, minHeight: 40)
                .background(
                    Capsule().fill(finished ? Color.foodrun.subject.positive.opacity(0.12) : Color.foodrun.neuTrack)
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(Color.foodrun.foreground)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }
}

// MARK: - Prep checklist (sheet)

/// The prep checklist — the same list, ticks and amounts as the prep portal.
/// Tap a row to tick it; the pencil opens the amount packed + a note.
struct CrewPrepListSheet: View {
    let store: EventStore
    @Environment(\.dismiss) private var dismiss
    @State private var editingPrep: CrewPrepItem?

    private var closed: Bool { store.event?.activity.is_closed ?? false }

    var body: some View {
        let items = store.event?.prep?.items ?? []
        let order = ["ingredients", "equipment", "rentals", "trailers", "addons"]
        let done = items.filter(\.checked).count
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CrewSheetHeader(title: FRLanguage.string("tasks.prep.title")) { dismiss() }
                if let error = store.lastError { CrewBriefingError(text: error) }
                if items.isEmpty {
                    CrewBriefingEmpty(key: "crew.prep.none")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(verbatim: String(format: FRLanguage.string("crew.prep.progress %lld %lld"), done, items.count))
                            .frText(FRType.rowTitle)
                        ProgressView(value: Double(done), total: Double(max(items.count, 1)))
                            .tint(Color.foodrun.subject.positive)
                    }
                }
                ForEach(order, id: \.self) { group in
                    let rows = items.filter { $0.section == group }
                    if !rows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(verbatim: FRLanguage.string("crew.prep.group.\(group)")).frText(FRType.sectionHeader)
                                Spacer()
                                Text(verbatim: "\(rows.filter(\.checked).count)/\(rows.count)")
                                    .frText(FRType.rowSubtitle).monospacedDigit()
                                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                            VStack(spacing: 0) {
                                ForEach(rows) { item in
                                    prepRow(item)
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
                    Text("crew.prep.shared")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .padding(20)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(item: $editingPrep) { item in
            CrewPrepSheet(item: item) { quantity, unitLevel, clearQuantity, comment in
                await store.detailPrep(item, quantity: quantity, unitLevel: unitLevel,
                                       clearQuantity: clearQuantity, comment: comment)
            }
        }
    }

    private func prepRow(_ item: CrewPrepItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                Task {
                    let ok = await store.togglePrep(item)
                    if ok { FRHaptic.light.fire() } else { FRHaptic.error.fire() }
                }
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        if store.savingPrep.contains(item.key) {
                            ProgressView()
                        } else {
                            Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 22))
                                .foregroundStyle(item.checked ? Color.foodrun.subject.positive : Color.foodrun.mutedForegroundSoft)
                        }
                    }
                    .frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: item.name)
                            .frText(FRType.rowTitle)
                            .strikethrough(item.checked, color: Color.foodrun.mutedForegroundSoft)
                            .foregroundStyle(item.checked ? Color.foodrun.mutedForegroundSoft : Color.foodrun.foreground)
                        if let instruction = item.instruction {
                            Label(instruction, systemImage: "info.circle")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(Color.foodrun.foreground)
                        }
                        if let packed = item.packed {
                            Text(verbatim: String(format: FRLanguage.string("crew.prep.packedLine %@"),
                                                  CrewFormat.quantity(packed, item.unitNames[safe: item.packed_level ?? 0] ?? item.unit)))
                                .frText(FRType.rowSubtitle).monospacedDigit()
                                .foregroundStyle(Color.foodrun.subject.positive)
                        }
                        if let comment = item.comment {
                            Text(verbatim: comment)
                                .frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.subject.agentNoteBlue)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(verbatim: CrewFormat.quantity(item.quantity, item.unit))
                        .frText(FRType.rowSubtitle).monospacedDigit()
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        .padding(.top, 2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(closed || store.savingPrep.contains(item.key))
            .accessibilityLabel(Text(verbatim: item.name))
            .accessibilityValue(Text(LocalizedStringKey(item.checked ? "crew.prep.packed" : "crew.prep.notPacked")))

            let hasDetail = item.packed != nil || item.comment != nil
            Button { editingPrep = item } label: {
                Image(systemName: hasDetail ? "pencil.circle.fill" : "square.and.pencil")
                    .font(.system(size: 17))
                    .foregroundStyle(hasDetail ? Color.foodrun.subject.agentNoteBlue : Color.foodrun.mutedForegroundSoft)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .disabled(closed)
            .accessibilityLabel(Text("crew.prep.edit"))
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Stock count (sheet)

/// Count what's left of each event product today. The count goes to HQ as an
/// observation; the stock itself only changes when the operator takes it over.
struct CrewStockListSheet: View {
    let store: EventStore
    let day: String
    @Environment(\.dismiss) private var dismiss
    @State private var counting: CrewStockProduct?

    private var closed: Bool { store.event?.activity.is_closed ?? false }

    var body: some View {
        let products = store.event?.stock?.products ?? []
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                CrewSheetHeader(title: FRLanguage.string("tasks.stock.title"),
                                subtitle: CrewFormat.day(day)) { dismiss() }
                if let error = store.lastError { CrewBriefingError(text: error) }
                if products.isEmpty { CrewBriefingEmpty(key: "crew.stock.none") }
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
                                if let note = mine?.note {
                                    Text(verbatim: note)
                                        .frText(FRType.rowSubtitle)
                                        .foregroundStyle(Color.foodrun.subject.agentNoteBlue)
                                }
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
                    .disabled(closed)
                }
                if !products.isEmpty {
                    Text("crew.stock.footnote")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .padding(20)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
        .sheet(item: $counting) { product in
            let mine = store.myCount(productId: product.product_id, on: day)
            CrewCountSheet(
                title: product.name,
                prompt: String(format: FRLanguage.string("crew.stock.prompt %@"), CrewFormat.day(day)),
                units: product.units,
                initialQuantity: mine?.quantity,
                initialUnitLevel: mine?.unit_level ?? 0,
                initialNote: mine?.note,
                onSave: { quantity, level, note in
                    await store.count(productId: product.product_id, on: day, quantity: quantity, unitLevel: level, note: note)
                },
                onClear: mine == nil ? nil : { await store.count(productId: product.product_id, on: day, quantity: nil, unitLevel: 0) }
            )
        }
    }
}

/// Title row of a full-height sheet, with a close button.
struct CrewSheetHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: title).font(.system(size: 24, weight: .bold))
                if let subtitle {
                    Text(verbatim: subtitle).frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.foodrun.card))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.close"))
        }
    }
}
