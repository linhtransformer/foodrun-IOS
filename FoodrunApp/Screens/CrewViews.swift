import SwiftUI

// Building blocks shared by the event screen and the Tasks tab: one task row,
// the dish sheet (recipe + ingredients) and the sheet for typing a value.

enum CrewFormat {
    static func number(_ value: Double) -> String {
        let f = NumberFormatter()
        f.locale = FRLanguage.locale
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 3
        return f.string(from: value as NSNumber) ?? "\(value)"
    }

    static func quantity(_ value: Double, _ unit: String?) -> String {
        guard let unit, !unit.isEmpty else { return number(value) }
        return "\(number(value)) \(unit)"
    }

    /// "wo 8 okt" / "Wed 8 Oct".
    static func day(_ key: String) -> String {
        guard let date = SchemaDates.date(key) else { return key }
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "EEE d MMM"
        return f.string(from: date)
    }

    static func kindLabel(_ kind: CrewTaskKind) -> String {
        switch kind {
        case .check: return FRLanguage.string("crew.kind.check")
        case .count: return FRLanguage.string("crew.kind.count")
        case .number: return FRLanguage.string("crew.kind.number")
        case .text: return FRLanguage.string("crew.kind.text")
        case .photo: return FRLanguage.string("crew.kind.photo")
        case .other: return ""
        }
    }

    /// Accepts "2,5" and "2.5".
    static func parse(_ input: String) -> Double? {
        Double(input.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// The event's price for a dish: "€ 14,00", or "3 munten" when the event
    /// sells in coins.
    static func price(_ dish: CrewDish) -> String? {
        if let coins = dish.coin_price {
            return String(format: FRLanguage.string("briefing.coins %@"), number(coins))
        }
        guard let price = dish.price, price > 0 else { return nil }
        let f = NumberFormatter()
        f.locale = FRLanguage.locale
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        return f.string(from: price as NSNumber)
    }

    /// Allergen key from HQ ("Dairy") → the label in the app's language.
    static func allergen(_ key: String) -> String {
        let localizationKey = "allergen.\(key)"
        let label = FRLanguage.string(localizationKey)
        return label == localizationKey ? key : label
    }

    /// "woensdag 8 oktober".
    static func longDay(_ key: String) -> String? {
        guard let date = SchemaDates.date(key) else { return nil }
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    /// One day, or "wo 8 okt – vr 10 okt".
    static func dateRange(_ start: String?, _ end: String?) -> String? {
        guard let start else { return nil }
        guard let end, end != start else { return longDay(start) ?? start }
        return "\(day(start)) – \(day(end))"
    }

    /// Server timestamp → "8 okt 14:02".
    static func timestamp(_ iso: String) -> String? {
        let plain = iso.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        guard let date = ISO8601DateFormatter().date(from: plain) else { return nil }
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.dateFormat = "d MMM HH:mm"
        return f.string(from: date)
    }

    /// Text with its web addresses tappable — operators paste links into notes.
    static func linkified(_ text: String) -> AttributedString {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return AttributedString(text)
        }
        var out = AttributedString()
        var cursor = text.startIndex
        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let url = match.url, let range = Range(match.range, in: text), range.lowerBound >= cursor else { continue }
            if cursor < range.lowerBound {
                out += AttributedString(String(text[cursor..<range.lowerBound]))
            }
            var link = AttributedString(String(text[range]))
            link.link = url
            out += link
            cursor = range.upperBound
        }
        if cursor < text.endIndex {
            out += AttributedString(String(text[cursor...]))
        }
        return out
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// One assigned task. Every kind uses the same card so the purpose reads at a
/// glance: type icon + type label + status on top, title / instructions /
/// event / chip in the middle, and one full-width action at the bottom —
/// grey while open, green with the answer once done (tap to change).
/// Tick tasks toggle in place; value and photo tasks open a sheet.
struct CrewTaskRow: View {
    let task: CrewTask
    let response: CrewTaskResponse?
    var eventName: String? = nil
    let isSaving: Bool
    let isClosed: Bool
    let onToggle: () -> Void
    let onAnswer: () -> Void
    let onOpenDish: (CrewDish) -> Void
    /// Tasks tab: tapping the event name opens the event screen.
    var onOpenEvent: (() -> Void)? = nil

    private var done: Bool { response?.done ?? false }
    private var isTick: Bool { task.kind == .check || task.kind == .other }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: task.title)
                    .frText(FRType.rowTitle)
                if let instructions = task.instructions, !instructions.isEmpty {
                    Text(verbatim: instructions)
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                eventLink
                refChip
            }
            actionButton
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: kindSymbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? Color.foodrun.subject.positive : Color.foodrun.foreground)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(done ? Color.foodrun.subject.positive.opacity(0.14) : Color.foodrun.neuTrack)
                )
            Text(LocalizedStringKey(kindKey))
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Spacer(minLength: 8)
            Text(LocalizedStringKey(done ? "crew.status.done" : "crew.status.open"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(done ? Color.foodrun.subject.positive : Color.foodrun.mutedForegroundSoft)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var eventLink: some View {
        if let eventName {
            if let onOpenEvent {
                Button(action: onOpenEvent) {
                    HStack(spacing: 4) {
                        Text(verbatim: eventName)
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                .buttonStyle(.plain)
            } else {
                Text(verbatim: eventName)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    /// The one action, same place and size for every kind.
    private var actionButton: some View {
        Button(action: isTick ? onToggle : onAnswer) {
            HStack(spacing: 6) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: done ? "checkmark" : actionSymbol)
                        .font(.system(size: 13, weight: .bold))
                    actionLabel
                }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(done ? Color.foodrun.subject.positive : Color.foodrun.foreground)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(
                Capsule().fill(done ? Color.foodrun.subject.positive.opacity(0.12) : Color.foodrun.neuTrack)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isSaving || isClosed)
        .opacity(isClosed ? 0.4 : 1)
        .accessibilityLabel(Text(LocalizedStringKey(isTick ? (done ? "crew.task.markOpen" : "crew.task.markDone") : actionKey)))
    }

    @ViewBuilder
    private var actionLabel: some View {
        if done, let value = valueText {
            Text(verbatim: value).monospacedDigit().lineLimit(1)
        } else {
            Text(LocalizedStringKey(actionKey))
        }
    }

    // MARK: - Per kind

    private var kindKey: String {
        switch task.kind {
        case .check, .other: return "crew.kind.check"
        case .count: return "crew.kind.count"
        case .number: return "crew.kind.number"
        case .text: return "crew.kind.text"
        case .photo: return "crew.kind.photo"
        }
    }

    private var kindSymbol: String {
        switch task.kind {
        case .check, .other: return "checkmark"
        case .count: return "number"
        case .number: return "textformat.123"
        case .text: return "text.alignleft"
        case .photo: return "camera"
        }
    }

    private var actionSymbol: String {
        switch task.kind {
        case .check, .other: return "circle"
        case .count, .number, .text: return "square.and.pencil"
        case .photo: return "camera"
        }
    }

    private var actionKey: String {
        switch task.kind {
        case .check, .other: return done ? "crew.task.doneLabel" : "crew.task.markDone"
        case .count, .number, .text: return "crew.task.fill"
        case .photo: return done ? "crew.photo.added" : "crew.photo.take"
        }
    }

    private var valueText: String? {
        guard let response, response.done else { return nil }
        if task.kind == .text { return response.value_text }
        guard let n = response.value_number else { return nil }
        return CrewFormat.quantity(n, task.unit)
    }

    @ViewBuilder
    private var refChip: some View {
        if let dish = task.dish {
            Button { onOpenDish(dish) } label: {
                chip(symbol: "fork.knife", label: dish.name, tappable: true)
            }
            .buttonStyle(.plain)
        } else if let product = task.product {
            chip(symbol: "shippingbox", label: product.name, tappable: false)
        }
    }

    private func chip(symbol: String, label: String, tappable: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
            Text(verbatim: label).font(.system(size: 12, weight: .semibold))
            if tappable { Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)) }
        }
        .foregroundStyle(Color.foodrun.foreground)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Capsule().fill(Color.foodrun.neuTrack))
        .padding(.top, 2)
    }
}

/// Recipe + ingredients for one dish (per serving, in the operator's units).
struct CrewDishSheet: View {
    let dish: CrewDish
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(verbatim: dish.name).font(.system(size: 24, weight: .bold))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.foodrun.foreground)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(Color.foodrun.card))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("action.close"))
                }
                if let url = dish.imageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable().scaledToFill()
                        } else {
                            Rectangle().fill(Color.foodrun.neuTrack)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous))
                    .accessibilityHidden(true)
                }
                if let price = CrewFormat.price(dish) {
                    Text(verbatim: price).font(.system(size: 20, weight: .bold).monospacedDigit())
                }
                if let description = dish.description {
                    Text(verbatim: description).frText(FRType.body).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                if let allergens = dish.allergens, !allergens.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("briefing.allergens").frText(FRType.fieldLabel)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        CrewAllergenChips(allergens: allergens)
                        if let may = dish.may_contain {
                            Text(verbatim: String(format: FRLanguage.string("briefing.mayContain %@"), may))
                                .frText(FRType.rowSubtitle)
                                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                        }
                    }
                }
                if let estimate = dish.estimated_quantity, estimate > 0 {
                    Text(verbatim: String(format: FRLanguage.string("crew.dish.portions %@"), CrewFormat.number(estimate)))
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }

                if !dish.ingredients.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("crew.dish.ingredients").frText(FRType.sectionHeader)
                        VStack(spacing: 0) {
                            ForEach(dish.ingredients) { ing in
                                HStack {
                                    Text(verbatim: ing.name).frText(FRType.rowTitle)
                                    Spacer()
                                    Text(verbatim: CrewFormat.quantity(ing.quantity, ing.unit))
                                        .frText(FRType.rowSubtitle)
                                        .monospacedDigit()
                                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                                }
                                .padding(.vertical, 10)
                                if ing.id != dish.ingredients.last?.id {
                                    Rectangle().fill(Color.foodrun.border).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                        Text("crew.dish.perServing")
                            .frText(FRType.rowSubtitle)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                }

                if let recipe = dish.recipe {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("crew.dish.recipe").frText(FRType.sectionHeader)
                        Text(verbatim: recipe)
                            .frText(FRType.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value).fill(Color.foodrun.card))
                    }
                }
            }
            .padding(20)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDragIndicator(.visible)
    }
}

/// Type a number (with unit) or a short text answer. Also used for stock
/// counts, where the worker can pick which unit they counted in.
struct CrewAnswerSheet: View {
    let title: String
    let prompt: String?
    let kind: CrewTaskKind
    let units: [String]
    let initialNumber: Double?
    let initialText: String?
    let initialUnitLevel: Int
    let canClear: Bool
    let onSave: (_ number: Double?, _ text: String?, _ unitLevel: Int) async -> Bool
    let onClear: () async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @State private var unitLevel: Int = 0
    @State private var working = false
    @FocusState private var focused: Bool

    private var isText: Bool { kind == .text }
    private var parsed: Double? { CrewFormat.parse(input) }
    private var canSave: Bool {
        if isText { return !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard let parsed else { return false }
        return kind != .count || parsed >= 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(verbatim: title).font(.system(size: 22, weight: .bold))
            if let prompt, !prompt.isEmpty {
                Text(verbatim: prompt).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }

            HStack(spacing: 10) {
                Group {
                    if isText {
                        TextField(FRLanguage.string("crew.answer.textPlaceholder"), text: $input, axis: .vertical)
                            .lineLimit(1...4)
                    } else {
                        TextField(String("0"), text: $input)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 28, weight: .bold).monospacedDigit())
                    }
                }
                .focused($focused)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))

                if !isText && units.count == 1 {
                    Text(verbatim: units[0]).frText(FRType.rowTitle)
                }
            }
            if !isText && units.count > 1 {
                CrewUnitChips(units: units, selection: $unitLevel)
            }

            Button {
                Task {
                    working = true
                    let ok = await onSave(isText ? nil : parsed, isText ? input : nil, unitLevel)
                    working = false
                    if ok { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire() }
                }
            } label: {
                ZStack {
                    if working { ProgressView().tint(Color.foodrun.backgroundInverseInk) } else { Text("crew.answer.save") }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.foodrun.foreground))
                .opacity(canSave ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || working)

            if canClear {
                Button {
                    Task {
                        working = true
                        let ok = await onClear()
                        working = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text("crew.answer.clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(working)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let initialNumber { input = CrewFormat.number(initialNumber) }
            if let initialText { input = initialText }
            unitLevel = min(max(initialUnitLevel, 0), max(units.count - 1, 0))
            focused = true
        }
    }
}

/// One prep row: the amount actually packed (in any unit of the product) and a
/// note, saved together. The amount is the prep portal's own amount for the
/// row, so the packer sees it there and HQ in the prep card.
struct CrewPrepSheet: View {
    let item: CrewPrepItem
    let onSave: (_ quantity: Double?, _ unitLevel: Int, _ clearQuantity: Bool, _ comment: String?) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var unitLevel = 0
    @State private var note = ""
    @State private var initialAmount = ""
    @State private var initialLevel = 0
    @State private var working = false
    @FocusState private var focus: Field?

    private enum Field { case amount, note }

    private var units: [String] { item.unitNames }
    private var trimmedAmount: String { amount.trimmingCharacters(in: .whitespaces) }
    private var parsed: Double? { CrewFormat.parse(amount) }
    private var amountValid: Bool {
        trimmedAmount.isEmpty || (parsed.map { $0 >= 0 && $0 < 1_000_000 } ?? false)
    }
    /// Compared with what the sheet opened with, so an untouched amount is not
    /// re-sent (and not re-attributed to this crew member).
    private var amountChanged: Bool {
        trimmedAmount != initialAmount || (!trimmedAmount.isEmpty && unitLevel != initialLevel)
    }
    private var noteChanged: Bool {
        note.trimmingCharacters(in: .whitespacesAndNewlines) != (item.comment ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: item.name).font(.system(size: 22, weight: .bold))
                Text(verbatim: String(format: FRLanguage.string("crew.prep.needed %@"),
                                      CrewFormat.quantity(item.quantity, item.unit)))
                    .frText(FRType.rowSubtitle).monospacedDigit()
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                if let instruction = item.instruction {
                    Label(instruction, systemImage: "info.circle")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.foodrun.foreground)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("crew.prep.amount").frText(FRType.sectionHeader)
                HStack(spacing: 10) {
                    TextField(String("0"), text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                        .focused($focus, equals: .amount)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
                    if units.count == 1 {
                        Text(verbatim: units[0]).frText(FRType.rowTitle)
                    }
                }
                if units.count > 1 {
                    CrewUnitChips(units: units, selection: $unitLevel)
                }
                Text("crew.prep.amountHint")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("crew.prep.noteLabel").frText(FRType.sectionHeader)
                TextField(FRLanguage.string("crew.prep.notePrompt"), text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($focus, equals: .note)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
            }

            Button {
                guard amountChanged || noteChanged else { dismiss(); return }
                Task {
                    working = true
                    let ok = await onSave(
                        amountChanged && !trimmedAmount.isEmpty ? parsed : nil,
                        unitLevel,
                        amountChanged && trimmedAmount.isEmpty,
                        noteChanged ? note.trimmingCharacters(in: .whitespacesAndNewlines) : nil
                    )
                    working = false
                    if ok { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire() }
                }
            } label: {
                ZStack {
                    if working { ProgressView().tint(Color.foodrun.backgroundInverseInk) } else { Text("crew.answer.save") }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.foodrun.foreground))
                .opacity(amountValid ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!amountValid || working)

            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let packed = item.packed { amount = CrewFormat.number(packed) }
            let level = item.packed_level ?? item.quantity_level ?? 0
            unitLevel = min(max(level, 0), max(units.count - 1, 0))
            initialAmount = amount
            initialLevel = unitLevel
            note = item.comment ?? ""
            focus = .amount
        }
    }
}

/// The units of a product as tappable chips ("doos · pak · ml"), so changing
/// the unit is obvious; the old menu picker read as plain text.
struct CrewUnitChips: View {
    let units: [String]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(units.enumerated()), id: \.offset) { idx, name in
                    let active = idx == selection
                    Button {
                        selection = idx
                        FRHaptic.light.fire()
                    } label: {
                        Text(verbatim: name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(Capsule().fill(active ? Color.foodrun.foreground : Color.foodrun.card))
                            .overlay(Capsule().stroke(Color.foodrun.border, lineWidth: active ? 0 : 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(active ? .isSelected : [])
                }
            }
        }
    }
}

/// Dish photo from HQ, or a fork-and-knife tile when the dish has none.
struct CrewDishThumb: View {
    let url: URL?
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.neuTrack)
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        Image(systemName: "fork.knife").font(.system(size: 15, weight: .medium))
                    }
                }
            } else {
                Image(systemName: "fork.knife").font(.system(size: 15, weight: .medium))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Count of one event product: the number, the unit it was counted in and an
/// optional note ("2 dozen nog in de vriezer"). Goes to HQ as a count; the
/// stock itself only changes when the operator takes it over.
struct CrewCountSheet: View {
    let title: String
    let prompt: String
    let units: [String]
    let initialQuantity: Double?
    let initialUnitLevel: Int
    let initialNote: String?
    let onSave: (_ quantity: Double, _ unitLevel: Int, _ note: String?) async -> Bool
    /// nil when there is no count yet.
    let onClear: (() async -> Bool)?

    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var unitLevel = 0
    @State private var note = ""
    @State private var working = false
    @FocusState private var amountFocused: Bool

    private var parsed: Double? { CrewFormat.parse(amount) }
    private var canSave: Bool { parsed.map { $0 >= 0 && $0 < 1_000_000 } ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: title).font(.system(size: 22, weight: .bold))
                Text(verbatim: prompt).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    TextField(String("0"), text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 28, weight: .bold).monospacedDigit())
                        .focused($amountFocused)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
                    if units.count == 1 {
                        Text(verbatim: units[0]).frText(FRType.rowTitle)
                    }
                }
                if units.count > 1 {
                    CrewUnitChips(units: units, selection: $unitLevel)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("crew.prep.noteLabel").frText(FRType.sectionHeader)
                TextField(FRLanguage.string("crew.stock.notePrompt"), text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.foodrun.surface))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.foodrun.border, lineWidth: 1))
            }

            Button {
                guard let parsed else { return }
                Task {
                    working = true
                    let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                    let ok = await onSave(parsed, unitLevel, trimmed.isEmpty ? nil : trimmed)
                    working = false
                    if ok { FRHaptic.success.fire(); dismiss() } else { FRHaptic.error.fire() }
                }
            } label: {
                ZStack {
                    if working { ProgressView().tint(Color.foodrun.backgroundInverseInk) } else { Text("crew.answer.save") }
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Capsule().fill(Color.foodrun.foreground))
                .opacity(canSave ? 1 : 0.4)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || working)

            if let onClear {
                Button {
                    Task {
                        working = true
                        let ok = await onClear()
                        working = false
                        if ok { dismiss() }
                    }
                } label: {
                    Text("crew.answer.clear")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .disabled(working)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .padding(.top, 8)
        .background(Color.foodrun.background.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if let initialQuantity { amount = CrewFormat.number(initialQuantity) }
            unitLevel = min(max(initialUnitLevel, 0), max(units.count - 1, 0))
            note = initialNote ?? ""
            amountFocused = true
        }
    }
}
