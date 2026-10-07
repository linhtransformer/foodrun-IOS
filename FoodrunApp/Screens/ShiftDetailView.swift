import SwiftUI

// Bundle §3 "Shift detail". Summary card + location + crew + gated checklist.

public struct ShiftDetailView: View {
    @Environment(TabRouter.self) private var router
    @Environment(ClockStore.self) private var clock
    @Environment(TasksStore.self) private var tasks
    @Environment(ScheduleStore.self) private var schedule
    @Environment(HoursStore.self) private var hours
    @Environment(ShiftChangeStore.self) private var changes
    @Environment(\.openURL) private var openURL

    public let activityId: UUID
    public let date: Date

    public init(activityId: UUID, date: Date) {
        self.activityId = activityId
        self.date = date
    }

    /// The rostered shift this screen shows (activity × day), from ScheduleStore.
    private var shift: WorkerShift? { schedule.shift(activityId: activityId, day: SchemaDates.string(date)) }
    private var activity: DBActivity? { shift?.activity ?? schedule.activities.first { $0.id == activityId } }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                summaryCard
                locationCard
                crewSection
                if AppConfig.Features.checklists { gateCard }
                nfcStrip
                if AppConfig.Features.shiftSwaps { requestSwap }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        // Seeing the shift counts as seeing the change.
        .onAppear { changes.markRead(activityId: activityId, day: SchemaDates.string(date)) }
    }

    private var header: some View {
        HStack {
            Button { router.popOnShifts() } label: {
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
            // Overflow "⋯" menu removed until it has real actions (Slice 11) —
            // App Review rejects buttons that do nothing.
        }
    }

    /// True when the opened shift is today's ongoing one — matches the black hero
    /// styling so the transition from home card → detail card feels continuous.
    private var isTodayShift: Bool {
        schedule.isToday(date)
    }

    private var summaryCard: some View {
        let ink: Color = isTodayShift ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground
        let sub: Color = isTodayShift ? Color.foodrun.backgroundInverseInk.opacity(0.6) : Color.foodrun.mutedForegroundSoft
        let statusFill: Color = isTodayShift
            ? Color.foodrun.subject.onTheClockGreen.opacity(0.18)
            : Color.foodrun.subject.positive.opacity(0.15)
        let statusInk: Color = isTodayShift
            ? Color.foodrun.subject.onTheClockGreen
            : Color.foodrun.subject.positive
        let divider: Color = isTodayShift
            ? Color.foodrun.backgroundInverseInk.opacity(0.15)
            : Color.foodrun.border

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle().fill(Color.foodrunData(hex: activity?.color)).frame(width: 7, height: 7)
                    Text(verbatim: activity?.food_truck ?? activity?.name ?? "").frText(FRType.eyebrow).foregroundStyle(ink)
                }
                Text("detail.status.confirmed")
                    .frText(FRType.fieldLabel)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(statusFill))
                    .foregroundStyle(statusInk)
                Spacer()
            }
            Text(verbatim: longDate)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(sub)
            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text(verbatim: shift?.start ?? "--:--").font(.system(size: 44, weight: .heavy).monospacedDigit()).tracking(-1.5)
                    .foregroundStyle(ink)
                Text(verbatim: "– \(shift?.end ?? "--:--")").font(.system(size: 17, weight: .semibold).monospacedDigit())
                    .foregroundStyle(sub)
            }
            Rectangle().fill(divider).frame(height: 1)
            HStack(spacing: 12) {
                col("detail.role", shift?.employee.roles?.first ?? "—", sub: sub, ink: ink)
                col("detail.break", "\(submitted?.break_minutes ?? 0) min", sub: sub, ink: ink)
                col("detail.hours", hoursLabel, sub: sub, ink: ink)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.hero.value, style: .continuous)
                .fill(isTodayShift ? Color.foodrun.foreground : Color.foodrun.card)
        )
        .shadow(color: .black.opacity(isTodayShift ? 0.22 : 0), radius: isTodayShift ? 14 : 0, y: isTodayShift ? 8 : 0)
        .modifier(SummaryCardNeu(applyNeu: !isTodayShift))
    }

    /// Only apply the neumorphic pair on the white card variant — on the black
    /// hero-matched card we use a single drop shadow like the home hero.
    private struct SummaryCardNeu: ViewModifier {
        let applyNeu: Bool
        func body(content: Content) -> some View {
            if applyNeu { content.frNeu(.raisedLg) } else { content }
        }
    }

    /// Hours the worker submitted for this day, if any (employee_hours).
    private var submitted: DBEmployeeHours? { hours.row(activityId: activityId, day: SchemaDates.string(date)) }

    private var hoursLabel: String {
        FRLanguage.hours(submitted?.hours ?? shift?.plannedHours ?? 0)
    }

    private var longDate: String {
        let f = DateFormatter(); f.locale = FRLanguage.locale; f.dateFormat = "EEEE d MMMM"
        return f.string(from: date)
    }

    private func col(_ label: LocalizedStringKey, _ value: String, sub: Color, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).frText(FRType.fieldLabel).foregroundStyle(sub)
            Text(value).frText(FRType.rowTitle).foregroundStyle(ink)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private var locationCard: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12).fill(Color.foodrun.neuTrack).frame(width: 56, height: 56)
                .overlay(Image(systemName: "map").foregroundStyle(Color.foodrun.mutedForegroundSoft))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: activity?.name ?? "—").frText(FRType.rowTitle)
                Text(verbatim: activity?.location ?? "").frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer()
            Button { openRoute() } label: {
                Text("detail.route")
                    .frText(FRType.segmented)
                    .foregroundStyle(Color.foodrun.foreground)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Capsule().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }

    /// Workers can only read their own employee row (RLS), so colleagues are
    /// shown as a headcount from activities.daily_employees, not by name.
    private var crewSection: some View {
        let day = SchemaDates.string(date)
        let others = max(0, (activity?.headcount(on: day) ?? 1) - 1)
        return VStack(alignment: .leading, spacing: 10) {
            Text("detail.crew").frText(FRType.sectionHeader)
            if let shift {
                FRRosterRow(name: shift.employee.fullName, initials: initials(shift.employee.fullName),
                            avatarColor: Color.foodrunData(hex: shift.activity.color),
                            role: shift.employee.roles?.first ?? "",
                            truckName: shift.activity.food_truck ?? shift.activity.name,
                            truckColor: Color.foodrunData(hex: shift.activity.color),
                            time: shift.start ?? "", isYou: true)
            }
            if others > 0 {
                Text("detail.crew.others \(others)")
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func openRoute() {
        guard let q = activity?.location?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(q)") else { return }
        openURL(url)
    }

    private var gateCard: some View {
        let today = schedule.isToday(date)
        let unlocked = today && clock.clockedIn
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.clipboard")
                    .foregroundStyle(Color.foodrun.foreground)
                Text("detail.gate.title").frText(FRType.rowTitle)
                Spacer()
                Image(systemName: "chevron.down")
                    .rotationEffect(.degrees(tasks.gateExpanded ? 180 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(FRAnimation.subtle) { tasks.gateExpanded.toggle() }
            }
            if tasks.gateExpanded {
                ForEach(tasks.items.prefix(3)) { item in
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 6).stroke(Color.foodrun.border).frame(width: 18, height: 18)
                        Text(item.title).frText(FRType.rowSubtitle)
                        Spacer()
                    }
                }
                if unlocked {
                    Button {
                        router.tab = .tasks
                    } label: {
                        HStack {
                            Text("detail.gate.open \(tasks.completed) \(tasks.items.count)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                            Spacer()
                            ProgressView(value: tasks.progress)
                                .frame(width: 80)
                                .tint(Color.foodrun.subject.onTheClockGreen)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Capsule().fill(Color.foodrun.foreground))
                    }.buttonStyle(.plain)
                } else {
                    lockedFooter(today: today)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
    }

    private func lockedFooter(today: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            Text(today ? "detail.gate.locked.today" : "detail.gate.locked.future")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.foodrun.background)
        )
    }

    private var nfcStrip: some View {
        Button { armNFCReader() } label: {
            HStack(spacing: 8) {
                Image(systemName: "wave.3.right")
                Text("detail.nfc.listening")
                    .frText(FRType.rowSubtitle)
            }
            .foregroundStyle(Color.foodrun.foreground)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.foodrun.mutedForegroundSoft.opacity(0.5),
                                  style: StrokeStyle(lineWidth: 1, dash: [4]))
            )
        }
        .buttonStyle(.plain)
    }

    private func armNFCReader() {
        // Clock against this worker's employee row at the activity's operator.
        guard let employeeId = shift?.employee.id ?? activity.flatMap({ schedule.employee(for: $0)?.id }) else {
            clock.lastError = "Sign in first to clock in."
            FRHaptic.warning.fire()
            return
        }
        clock.activityId = activityId
        NFCReader.shared.start(hint: clock.clockedIn ? "Hold your phone to the tag to clock out" : "Hold your phone to the tag to clock in") { result in
            switch result {
            case .tag(_, let url):
                guard let url else {
                    clock.lastError = "That tag isn't readable — try again."
                    FRHaptic.warning.fire()
                    return
                }
                Task { await clock.handleTagRead(url: url, employeeId: employeeId) }
            case .cancelled:
                break
            case .error(let e):
                clock.lastError = e.localizedDescription
                FRHaptic.error.fire()
            case .unavailable:
                clock.lastError = "This iPhone doesn't support NFC clock-in."
                FRHaptic.error.fire()
            }
        }
    }

    private var requestSwap: some View {
        Button {
            router.swapSheetOpen = true
        } label: {
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                Text("detail.requestSwap")
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.foodrun.foreground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .overlay(Capsule().stroke(Color.foodrun.foreground, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
