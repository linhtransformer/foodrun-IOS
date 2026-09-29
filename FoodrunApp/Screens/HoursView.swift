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
                    timeStepper("hours.tile.start", value: editStart) { editStart = shiftTime(editStart, $0) }
                    timeStepper("hours.tile.end", value: editEnd) { editEnd = shiftTime(editEnd, $0) }
                    timeStepper("hours.tile.break", value: "\(editBreak)m") { editBreak = max(0, editBreak + $0) }
                }
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "sparkles").foregroundStyle(Color.foodrun.subject.agentNoteBlue)
                    Text("hours.prefill.note").frText(FRType.rowSubtitle)
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.agentNoteField))
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
    }

    private func timeStepper(_ label: LocalizedStringKey, value: String, step: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
            HStack(spacing: 4) {
                stepButton("minus") { step(-15) }
                Text(value)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                stepButton("plus") { step(15) }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.background))
        .frNeu(.pressed)
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: { action(); FRHaptic.light.fire() }) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.foodrun.foreground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Color.foodrun.card).frame(width: 24, height: 24))
        }
        .buttonStyle(.plain)
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
        editStart = shift.start ?? "09:00"
        editEnd = shift.end ?? "17:00"
        editBreak = hours.row(activityId: shift.activity.id, day: shift.day)?.break_minutes ?? 0
    }

    private func shiftTime(_ t: String, _ delta: Int) -> String {
        let total = ((Int(t.prefix(2)) ?? 0) * 60 + (Int(t.suffix(2)) ?? 0) + delta + 1440) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
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
