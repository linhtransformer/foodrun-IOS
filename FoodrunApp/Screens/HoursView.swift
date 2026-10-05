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

    /// Which due shift's card is open. Defaults to the first; nil after the
    /// worker folds the open one.
    @State private var expandedShiftId: String?
    @State private var collapsedAll = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                monthStepper
                kpis
                if !dueShifts.isEmpty || !runningShifts.isEmpty { waitingForYou }
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

    /// Finished shifts with no hours yet, or hours the operator sent back.
    /// A shift only becomes submittable once its end time has passed.
    private var dueShifts: [WorkerShift] {
        let now = Date()
        return schedule.shifts.filter { shift in
            guard shift.endsAt <= now else { return false }
            let row = hours.row(activityId: shift.activity.id, day: shift.day)
            return row == nil || row?.status == .rejected
        }
    }

    /// Today's shifts that haven't ended yet: shown locked, with when they open.
    private var runningShifts: [WorkerShift] {
        let now = Date()
        let todayKey = SchemaDates.string(now)
        return schedule.shifts.filter { shift in
            shift.day == todayKey && shift.endsAt > now
                && hours.row(activityId: shift.activity.id, day: shift.day) == nil
        }
    }

    private var openShiftId: String? {
        if collapsedAll { return nil }
        if let id = expandedShiftId, dueShifts.contains(where: { $0.id == id }) { return id }
        return dueShifts.first?.id
    }

    private var monthRows: [DBEmployeeHours] {
        hours.rows.filter { Calendar.current.isDate($0.workDay, equalTo: hours.shownMonth, toGranularity: .month) }
    }

    // MARK: - Sections

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
            Button {
                router.hoursPath.append(.approvedHours)
                FRHaptic.light.fire()
            } label: {
                kpi("hours.approvedLabel", value: hours.approvedMonthTotal, color: Color.foodrun.foreground,
                    sub: "hours.thisMonth", showsChevron: true)
            }
            .buttonStyle(.plain)
            kpi("hours.pendingLabel", value: hours.pendingMonthTotal, color: Color.foodrun.subject.warning,
                sub: "hours.dueCount \(dueShifts.count)")
        }
    }

    private func kpi(_ label: LocalizedStringKey, value: Double, color: Color, sub: LocalizedStringKey,
                     showsChevron: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).frText(FRType.fieldLabel).foregroundStyle(Color.foodrun.mutedForegroundSoft)
                if showsChevron {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
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

    private var waitingForYou: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("hours.waitingForYou").frText(FRType.sectionHeader)
                Spacer()
                if !dueShifts.isEmpty {
                    Text(verbatim: FRLanguage.string("hours.dueCount %lld", dueShifts.count))
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            ForEach(dueShifts) { shift in
                SubmitHoursCard(shift: shift, expanded: openShiftId == shift.id) {
                    withAnimation(FRAnimation.subtle) {
                        if openShiftId == shift.id {
                            collapsedAll = true
                        } else {
                            collapsedAll = false
                            expandedShiftId = shift.id
                        }
                    }
                }
            }
            ForEach(runningShifts) { shift in
                lockedRow(shift)
            }
        }
    }

    /// A shift still in progress: visible, but hours open only after it ends.
    private func lockedRow(_ shift: WorkerShift) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(dayLabel(shift.date)) · \(shift.activity.name)")
                    .frText(FRType.rowTitle)
                    .lineLimit(1)
                Text("hours.availableFrom \(endTime(shift))")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .strokeBorder(Color.foodrun.border, style: StrokeStyle(lineWidth: 1, dash: [4]))
        )
    }

    private func endTime(_ shift: WorkerShift) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: shift.endsAt)
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

    private var monthName: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; f.locale = FRLanguage.locale
        return f.string(from: hours.shownMonth)
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: date)
    }

    private func formatHours(_ v: Double) -> String { FRLanguage.hours(v) }
}
