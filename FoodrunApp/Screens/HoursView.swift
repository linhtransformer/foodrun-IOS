import SwiftUI

// Bundle §5. Hours.
//
// "Waiting for you" is the worker half of the hours loop: a past rostered shift
// with no hours submitted yet (or hours the operator rejected). Submitting
// upserts employee_hours with status 'pending' — the row then appears in HQ →
// Stakeholders → Uren for the operator to approve, and the decision comes back
// here and in the inbox.

public struct HoursView: View {
    @Environment(HoursStore.self) private var hours
    @Environment(ScheduleStore.self) private var schedule
    @Environment(TabRouter.self) private var router

    @State private var editStart = "09:00"
    @State private var editEnd = "17:00"
    @State private var editBreak = 0
    @State private var editingShiftId: String?
    @State private var editingField: TimeField?
    @State private var tapWindow: TapWindow?

    private enum TimeField { case start, end, brk }

    /// First phone-tap clock-in and the clock-out after it, for the shift being submitted.
    private struct TapWindow: Equatable {
        let clockIn: Date
        let clockOut: Date?
    }

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                monthStepper
                kpis
                if let shift = dueShifts.first { waitingForYou(shift) }
                monthLog
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable {
            await hours.load(employeeIds: schedule.employees.map(\.id))
        }
    }

    // MARK: - Derived

    /// Past (or today's) rostered shifts with no hours yet, or hours sent back.
    private var dueShifts: [WorkerShift] {
        let todayKey = SchemaDates.string(schedule.today)
        return schedule.shifts.filter { shift in
            guard shift.day <= todayKey else { return false }
            let row = hours.row(activityId: shift.activity.id, day: shift.day)
            return row == nil || row?.status == .rejected
        }
    }

    private var monthRows: [DBEmployeeHours] {
        hours.rows.filter { Calendar.current.isDate($0.workDay, equalTo: hours.shownMonth, toGranularity: .month) }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(periodKicker).frText(FRType.kicker).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Text("hours.title").frText(FRType.screenTitle)
            }
            Spacer()
            Button {
                router.hoursPath.append(.approvedHours)
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(Color.foodrun.subject.positive).frame(width: 6, height: 6)
                    Text("hours.approved").frText(FRType.segmented)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Capsule().fill(Color.foodrun.card))
                .frNeu(.raised)
            }
            .buttonStyle(.plain)
        }
    }

    private var monthStepper: some View {
        @Bindable var h = hours
        return HStack(spacing: 10) {
            arrow("chevron.left", label: "action.back") { h.hoursMonthOffset -= 1 }
            Spacer()
            Text(monthName).frText(FRType.rowTitle)
            Spacer()
            arrow("chevron.right", label: "action.more") { h.hoursMonthOffset += 1 }
        }
        .padding(6)
        .background(Capsule().fill(Color.foodrun.neuTrack))
    }

    private func arrow(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(FRAnimation.monthStep) { action() }; FRHaptic.light.fire() }) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.foodrun.neuPill).frame(width: 30, height: 30))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    private var kpis: some View {
        HStack(spacing: 10) {
            kpi("hours.approvedLabel", value: hours.approvedMonthTotal, color: Color.foodrun.foreground, sub: "hours.thisMonth")
            kpi("hours.pendingLabel", value: hours.pendingMonthTotal, color: Color.foodrun.subject.warning,
                sub: "hours.dueCount \(dueShifts.count)")
        }
    }

    private func kpi(_ label: LocalizedStringKey, value: Double, color: Color, sub: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(formatHours(value))
                .font(.system(size: 34, weight: .heavy).monospacedDigit())
                .tracking(-1)
                .foregroundStyle(color)
            Text(sub).frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: FRRadius.container.value, style: .continuous).fill(Color.foodrun.card))
        .frNeu(.raisedLg)
    }

    private func waitingForYou(_ shift: WorkerShift) -> some View {
        let rejected = hours.row(activityId: shift.activity.id, day: shift.day)
        let payable = payableHours
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("hours.waitingForYou").frText(FRType.sectionHeader)
                Spacer()
                if dueShifts.count > 1 {
                    Text("hours.moreDue \(dueShifts.count - 1)").frText(FRType.rowSubtitle).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            if let tapWindow { tapCard(tapWindow) }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle().fill(Color.foodrunData(hex: shift.activity.color)).frame(width: 8, height: 8)
                    Text(verbatim: "\(dayLabel(shift.date)) · \(shift.activity.food_truck ?? shift.activity.name)").frText(FRType.rowTitle)
                    Spacer()
                }
                Text([shift.activity.name, shift.activity.location].compactMap { $0 }.joined(separator: " · "))
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)

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
                if let err = hours.lastError {
                    Text(err).font(.system(size: 12)).foregroundStyle(Color.foodrun.subject.destructive)
                }
                Button {
                    Task {
                        if await hours.submit(shift: shift, hours: payable, breakMinutes: editBreak, comment: nil) {
                            FRHaptic.success.fire()
                        } else {
                            FRHaptic.error.fire()
                        }
                    }
                } label: {
                    Text("hours.submit \(formatHours(payable))")
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
        .onAppear { prefill(shift) }
        .onChange(of: shift.id) { _, _ in prefill(shift) }
        .task(id: shift.id) { await loadTapWindow(shift) }
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

    private var monthLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(monthName).frText(FRType.sectionHeader)
            if monthRows.isEmpty {
                Text("hours.monthEmpty")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                            .strokeBorder(Color.foodrun.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    )
            }
            VStack(spacing: 6) {
                ForEach(monthRows) { row in
                    let activity = schedule.activities.first { $0.id == row.activity_id }
                    FRHoursRow(
                        truckColor: Color.foodrunData(hex: activity?.color),
                        dayLabel: dayLabel(row.workDay),
                        venue: activity?.name ?? "—",
                        hours: row.hours,
                        status: row.status
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private var payableHours: Double {
        func m(_ t: String) -> Int { (Int(t.prefix(2)) ?? 0) * 60 + (Int(t.suffix(2)) ?? 0) }
        var mins = m(editEnd) - m(editStart)
        if mins < 0 { mins += 1440 }
        return Double(max(0, mins - editBreak)) / 60
    }

    private func prefill(_ shift: WorkerShift) {
        guard editingShiftId != shift.id else { return }
        editingShiftId = shift.id
        editingField = nil
        editStart = String((shift.start ?? "09:00").prefix(5))
        editEnd = String((shift.end ?? "17:00").prefix(5))
        editBreak = hours.row(activityId: shift.activity.id, day: shift.day)?.break_minutes ?? 0
    }

    private func loadTapWindow(_ shift: WorkerShift) async {
        tapWindow = nil
        guard let events = try? await WorkerAPI.fetchClockEvents(
            employeeId: shift.employee.id, activityId: shift.activity.id, day: shift.day
        ), let clockIn = events.first(where: { $0.kind == .`in` }) else { return }
        let clockOut = events.last { $0.kind == .out && $0.event_at > clockIn.event_at }
        tapWindow = TapWindow(clockIn: clockIn.event_at, clockOut: clockOut?.event_at)
    }

    private func clockTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
    }

    private var periodKicker: String {
        let f = DateFormatter(); f.dateFormat = "MMMM"; f.locale = .autoupdatingCurrent
        return f.string(from: hours.shownMonth).uppercased()
    }

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = .autoupdatingCurrent
        return f.string(from: hours.shownMonth)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = .autoupdatingCurrent
        return f.string(from: date)
    }

    private func formatHours(_ v: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "nl_NL")
        f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
        return "\(f.string(from: v as NSNumber) ?? "0,0") u"
    }
}
