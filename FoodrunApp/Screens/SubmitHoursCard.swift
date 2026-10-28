import SwiftUI

// One finished shift waiting for hours (Hours → Waiting for you). Folded it's a
// single row; open it shows the phone-tap times (read-only), the editable
// start / end / break wheels and the submit button. Each card keeps its own
// edits, so several shifts can be filled in one after another.

struct SubmitHoursCard: View {
    @Environment(HoursStore.self) private var hours

    let shift: WorkerShift

    @State private var editStart = "09:00"
    @State private var editEnd = "17:00"
    @State private var editBreak = 0
    /// Optional note for the manager (employee_hours.comment).
    @State private var note = ""
    @State private var prefilled = false
    @State private var editingField: TimeField?
    @State private var tapWindow: TapWindow?
    /// The clock events were looked up and there were none: the worker forgot to clock (C1).
    @State private var noClockEvents = false
    @FocusState private var noteFocused: Bool

    private enum TimeField { case start, end, brk }

    /// First phone-tap clock-in and the clock-out after it, for this shift.
    private struct TapWindow: Equatable {
        let clockIn: Date
        let clockOut: Date?
    }

    var body: some View {
        let rejected = hours.row(activityId: shift.activity.id, day: shift.day)
        let payable = payableHours
        VStack(alignment: .leading, spacing: 10) {
            if let tapWindow, tapWindow.clockOut != nil { tapCard(tapWindow) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(Color.foodrunData(hex: shift.activity.color)).frame(width: 8, height: 8)
                    Text(verbatim: "\(dayLabel(shift.date)) · \(shift.activity.food_truck ?? shift.activity.name)")
                        .frText(FRType.rowTitle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }

                Text([shift.activity.name, shift.activity.location].compactMap { $0 }.joined(separator: " · "))
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)

                if noClockEvents {
                    warning("hours.noClock.title", "hours.noClock.body")
                } else if let tapWindow, tapWindow.clockOut == nil {
                    // Clocked in, never out: the shift has ended, so the worker forgot (C3).
                    warning(LocalizedStringKey(String(format: FRLanguage.string("hours.noClockOut.title %@"),
                                                      clockTime(tapWindow.clockIn))),
                            "hours.noClockOut.body")
                }

                if let rejected, rejected.status == .rejected {
                    Text("hours.rejected \(rejected.rejected_reason ?? "")")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.subject.destructive.opacity(0.1)))
                }

                HStack(spacing: 8) {
                    timeTile("hours.tile.start", value: editStart, field: .start)
                    timeTile("hours.tile.end", value: editEnd, field: .end)
                    timeTile("hours.tile.break", value: "\(editBreak) min", field: .brk)
                }
                if let editingField {
                    wheel(for: editingField)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                TextField(noClockEvents || tapWindow?.clockOut == nil && tapWindow != nil
                          ? "hours.noClock.notePlaceholder" : "hours.note.placeholder",
                          text: $note, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($noteFocused)
                    .submitLabel(.done)
                    // Return closes the keyboard (a multi-line field would add a line), so the
                    // send button underneath is reachable.
                    .onChange(of: note) { _, value in
                        if value.hasSuffix("\n") {
                            note = String(value.dropLast())
                            noteFocused = false
                        }
                    }
                    .font(.system(size: 14))
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.background))
                    .frNeu(.pressed)
                    .accessibilityLabel(Text("hours.note.label"))
                if let err = hours.lastError {
                    Text(err).font(.system(size: 12)).foregroundStyle(Color.foodrun.subject.destructive)
                }
                Button {
                    Task {
                        if await hours.submit(shift: shift, hours: payable, breakMinutes: editBreak, comment: trimmedNote,
                                              start: editStart, end: editEnd) {
                            FRHaptic.success.fire()
                        } else {
                            FRHaptic.error.fire()
                        }
                    }
                } label: {
                    Text("hours.submit \(FRLanguage.hours(payable))")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.foodrun.backgroundInverseInk)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(Capsule().fill(payable > 0 ? Color.foodrun.foreground : Color.foodrun.disabledInk))
                        .frCTAShadow()
                }
                .buttonStyle(.plain)
                .disabled(hours.isSubmitting || payable <= 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous).fill(Color.foodrun.card))
            .frNeu(.raised)
        }
        .onAppear(perform: prefill)
        .task(id: shift.id) { await loadTapWindow() }
    }

    /// No clock-in on this shift: say so before the worker sends roster times, so the manager
    /// isn't surprised and the note explains what happened.
    private func warning(_ title: LocalizedStringKey, _ body: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.foodrun.subject.warning)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).frText(FRType.rowTitle)
                Text(body)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.foodrun.subject.warning.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }

    /// Read-only: the times the NFC tag recorded. Kept apart from the editable
    /// tiles so it's clear these come from the clock, not from the worker.
    private func tapCard(_ window: TapWindow) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "wave.3.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.foodrun.foreground))
            VStack(alignment: .leading, spacing: 3) {
                Text("hours.tap.title").frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Text(verbatim: "\(clockTime(window.clockIn)) – \(window.clockOut.map(clockTime) ?? "…")")
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.foodrun.foreground)
                Text(window.clockOut == nil ? "hours.tap.stillIn" : "hours.tap.locked")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer(minLength: 0)
            Image(systemName: "lock.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raised)
        .accessibilityElement(children: .combine)
    }

    private func timeTile(_ label: LocalizedStringKey, value: String, field: TimeField) -> some View {
        let selected = editingField == field
        return Button {
            withAnimation(FRAnimation.subtle) { editingField = selected ? nil : field }
            FRHaptic.light.fire()
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Text(value)
                    .font(.system(size: 20, weight: .semibold).monospacedDigit())
                    .foregroundStyle(Color.foodrun.foreground)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.background))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? Color.foodrun.foreground : .clear, lineWidth: 1.5)
            )
            .frNeu(.pressed)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func wheel(for field: TimeField) -> some View {
        switch field {
        case .start: timeWheel($editStart)
        case .end: timeWheel($editEnd)
        case .brk: breakWheel
        }
    }

    /// Hour and minute wheels bound to an "HH:mm" string.
    private func timeWheel(_ time: Binding<String>) -> some View {
        let hour = Binding<Int>(
            get: { Int(time.wrappedValue.prefix(2)) ?? 0 },
            set: { time.wrappedValue = String(format: "%02d:%02d", $0, Int(time.wrappedValue.suffix(2)) ?? 0) }
        )
        let minute = Binding<Int>(
            get: { Int(time.wrappedValue.suffix(2)) ?? 0 },
            set: { time.wrappedValue = String(format: "%02d:%02d", Int(time.wrappedValue.prefix(2)) ?? 0, $0) }
        )
        return HStack(spacing: 0) {
            Picker("hours.tile.hour", selection: hour) {
                ForEach(0..<24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            Text(verbatim: ":").font(.system(size: 20, weight: .semibold))
            Picker("hours.tile.minute", selection: minute) {
                ForEach(0..<60, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
        }
        .frame(height: 150)
    }

    private var breakWheel: some View {
        // 5-minute steps, plus whatever odd value an earlier submission stored.
        let options = Array(Set(Array(stride(from: 0, through: 240, by: 5)) + [editBreak])).sorted()
        return Picker("hours.tile.break", selection: $editBreak) {
            ForEach(options, id: \.self) { Text(verbatim: "\($0) min").tag($0) }
        }
        .pickerStyle(.wheel)
        .frame(height: 150)
    }

    // MARK: - Helpers

    private var payableHours: Double {
        func m(_ t: String) -> Int { (Int(t.prefix(2)) ?? 0) * 60 + (Int(t.suffix(2)) ?? 0) }
        var mins = m(editEnd) - m(editStart)
        if mins < 0 { mins += 1440 }
        return Double(max(0, mins - editBreak)) / 60
    }

    private var trimmedNote: String? {
        let t = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private func prefill() {
        guard !prefilled else { return }
        prefilled = true
        editStart = String((shift.start ?? "09:00").prefix(5))
        editEnd = String((shift.end ?? "17:00").prefix(5))
        let existing = hours.row(activityId: shift.activity.id, day: shift.day)
        // The planner's pauze for this shift until the worker submitted their own.
        editBreak = existing?.break_minutes ?? shift.breakMinutes ?? 0
        note = existing?.comment ?? ""
    }

    private func loadTapWindow() async {
        tapWindow = nil
        noClockEvents = false
        guard let events = try? await WorkerAPI.fetchClockEvents(
            employeeId: shift.employee.id, activityId: shift.activity.id, day: shift.day
        ) else { return }   // couldn't look: say nothing rather than something wrong
        guard let clockIn = events.first(where: { $0.kind == .`in` }) else {
            noClockEvents = true
            return
        }
        let clockOut = events.last { $0.kind == .out && $0.event_at > clockIn.event_at }
        tapWindow = TapWindow(clockIn: clockIn.event_at, clockOut: clockOut?.event_at)
    }

    private func clockTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: date)
    }
}
