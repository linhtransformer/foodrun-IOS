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
}

/// One assigned task. Tick tasks toggle in place; value tasks open a sheet.
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if task.kind == .check || task.kind == .other {
                Button(action: onToggle) {
                    ZStack {
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .regular))
                                .foregroundStyle(done ? Color.foodrun.subject.positive : Color.foodrun.mutedForegroundSoft)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(isSaving || isClosed)
                .accessibilityLabel(Text(LocalizedStringKey(done ? "crew.task.markOpen" : "crew.task.markDone")))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: task.title)
                    .frText(FRType.rowTitle)
                    .strikethrough(done && task.kind == .check, color: Color.foodrun.mutedForegroundSoft)
                    .foregroundStyle(done && task.kind == .check ? Color.foodrun.mutedForegroundSoft : Color.foodrun.foreground)
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
                if let instructions = task.instructions, !instructions.isEmpty {
                    Text(verbatim: instructions)
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                refChip
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if task.kind.asksValue {
                Button(action: onAnswer) {
                    Group {
                        if isSaving {
                            ProgressView()
                        } else if let value = valueText {
                            Text(verbatim: value).monospacedDigit()
                        } else {
                            Text("crew.task.fill")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(done ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(done ? Color.foodrun.foreground : Color.foodrun.neuTrack))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || isClosed)
            } else if task.kind == .photo {
                Button(action: onAnswer) {
                    Group {
                        if isSaving {
                            ProgressView()
                        } else {
                            HStack(spacing: 5) {
                                Image(systemName: done ? "checkmark" : "camera")
                                Text(LocalizedStringKey(done ? "crew.photo.added" : "crew.photo.add"))
                            }
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(done ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(done ? Color.foodrun.foreground : Color.foodrun.neuTrack))
                }
                .buttonStyle(.plain)
                .disabled(isSaving || isClosed)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
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
                if let description = dish.description {
                    Text(verbatim: description).frText(FRType.body).foregroundStyle(Color.foodrun.mutedForegroundSoft)
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

                if !isText && !units.isEmpty {
                    if units.count > 1 {
                        Picker(selection: $unitLevel) {
                            ForEach(Array(units.enumerated()), id: \.offset) { idx, name in
                                Text(verbatim: name).tag(idx)
                            }
                        } label: { EmptyView() }
                        .pickerStyle(.menu)
                        .tint(Color.foodrun.foreground)
                    } else {
                        Text(verbatim: units[0]).frText(FRType.rowTitle)
                    }
                }
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
