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
    @Environment(ClockStore.self) private var clock
    /// Shift ids clocked out of today (see loadClockedOut).
    @State private var clockedOut: Set<String> = []

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
        .scrollDismissesKeyboard(.interactively)
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable {
            await hours.load(employeeIds: schedule.historyEmployeeIds)
            await loadClockedOut()
        }
        // On opening the tab and after every clock-in / clock-out.
        .task(id: "\(clock.clockedIn)|\(clock.latestEventKind.map { "\($0)" } ?? "")") { await loadClockedOut() }
    }

    // MARK: - Derived

    /// Finished shifts with no hours yet, or hours the operator sent back, newest first.
    /// A shift becomes submittable once its end time has passed, or as soon as the worker
    /// clocked out of it (left early, or done). At an employer the worker has left, only
    /// until 14 days after leaving; after that the shift drops off (its hours stay in the
    /// month log).
    private var dueShifts: [WorkerShift] {
        let now = Date()
        return schedule.shifts.filter { shift in
            guard shift.endsAt <= now || clockedOut.contains(shift.id), shift.acceptsHours(now: now) else { return false }
            let row = hours.row(activityId: shift.activity.id, day: shift.day)
            return row == nil || row?.status == .rejected
        }
        .sorted { ($0.day, $0.start ?? "") > ($1.day, $1.start ?? "") }
    }

    /// Today's shifts that haven't ended yet and aren't clocked out: shown locked, with when
    /// they open.
    private var runningShifts: [WorkerShift] {
        let now = Date()
        let todayKey = SchemaDates.string(now)
        return schedule.shifts.filter { shift in
            shift.day == todayKey && shift.endsAt > now && !shift.isAtFormerEmployer
                && !clockedOut.contains(shift.id)
                && hours.row(activityId: shift.activity.id, day: shift.day) == nil
        }
        .sorted { ($0.start ?? "") > ($1.start ?? "") }
    }

    /// Today's shifts whose latest clock event is a clock-out.
    private func loadClockedOut() async {
        let todayKey = SchemaDates.string(Date())
        var done: Set<String> = []
        for shift in schedule.shifts where shift.day == todayKey && !shift.isAtFormerEmployer {
            guard let events = try? await WorkerAPI.fetchClockEvents(
                employeeId: shift.employee.id, activityId: shift.activity.id, day: shift.day) else { continue }
            if events.sorted(by: { $0.event_at < $1.event_at }).last?.kind == .out { done.insert(shift.id) }
        }
        clockedOut = done
    }

    /// Submitted hours of the shown month, newest day first.
    private var monthRows: [DBEmployeeHours] {
        hours.rows
            .filter { Calendar.current.isDate($0.workDay, equalTo: hours.shownMonth, toGranularity: .month) }
            .sorted { $0.work_date > $1.work_date }
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
            // Newest first: today's running shifts, then the finished ones from new to old.
            ForEach(runningShifts) { shift in
                lockedRow(shift)
            }
            ForEach(dueShifts) { shift in
                SubmitHoursCard(shift: shift)
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
                // Same row as the Shifts list: date block, shift time, place, and on
                // the right the review status with the hours that were submitted.
                ForEach(monthRows) { row in
                    let activity = schedule.activities.first { $0.id == row.activity_id }
                    let shift = schedule.shift(activityId: row.activity_id, day: row.work_date)
                    let status = statusFor(row.status)
                    FRShiftRow(
                        density: .compact,
                        time: shift?.timeLabel ?? formatHours(row.hours),
                        truckName: activity?.food_truck ?? activity?.name ?? "",
                        truckColor: Color.foodrunData(hex: activity?.color),
                        venue: activity?.location ?? activity?.name ?? "—",
                        role: formatHours(row.hours),
                        status: status.label,
                        statusColor: status.color,
                        date: row.workDay
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

    private func statusFor(_ status: HoursStatus) -> (label: String, color: Color) {
        switch status {
        case .pending:
            return (FRLanguage.string("hours.status.pending").uppercased(with: FRLanguage.locale), Color.foodrun.subject.warning)
        case .approved:
            return (FRLanguage.string("hours.status.approved").uppercased(with: FRLanguage.locale), Color.foodrun.subject.positive)
        case .rejected:
            return (FRLanguage.string("hours.status.rejected").uppercased(with: FRLanguage.locale), Color.foodrun.subject.destructive)
        }
    }
}
