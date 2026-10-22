import SwiftUI

// Bundle §2. Home screen: next-shift hero + mode pills (+ week carousel on
// Roster / Availability) + mode body. All shift data comes from ScheduleStore,
// i.e. the roster the operator maintains in HQ.

public struct ShiftsView: View {
    @Environment(TabRouter.self) private var router
    @Environment(ScheduleStore.self) private var schedule
    @Environment(ClockStore.self) private var clock
    @Environment(AvailabilityStore.self) private var availability
    @Environment(TasksStore.self) private var tasks

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                modePills
                if schedule.mode != .shifts {
                    weekCarousel
                }
                modeBody
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable { await schedule.load() }
        .task(id: schedule.nextShift?.id) {
            // Refresh clocked-in state for the next shift — picks up events
            // written elsewhere (operator correcting a clock in HQ, another device).
            guard let shift = schedule.nextShift else { return }
            clock.activityId = shift.activity.id
            await clock.refreshLatestEvent(employeeId: shift.employee.id)
        }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        if let shift = schedule.nextShift {
            heroCard(shift)
        } else {
            emptyHero
        }
    }

    private func heroCard(_ shift: WorkerShift) -> some View {
        @Bindable var scheduleBindable = schedule
        return FRNextShiftCard(
            start: shift.start ?? "--:--",
            end: shift.end ?? "--:--",
            dayLabel: dayLabel(shift.date),
            role: shift.employee.roles?.first ?? "",
            truckName: shift.activity.food_truck ?? shift.activity.name,
            truckColor: Color.foodrunData(hex: shift.activity.color),
            location: [shift.activity.name, shift.activity.location].compactMap { $0 }.joined(separator: " · "),
            clockedIn: clock.clockedIn,
            elapsed: clock.elapsed,
            plannedDuration: max(shift.plannedHours, 1) * 3600,
            expanded: $scheduleBindable.heroExpanded,
            onTapListening: { armNFCReader(for: shift) },
            onTapChecklist: { openTasksIfUnlocked(shift) },
            checklistProgress: (tasks.completed, tasks.items.count)
        )
        .onTapGesture {
            // Whole card opens detail (bundle §Next-shift hero).
            router.pushOnShifts(.shiftDetail(activityId: shift.activity.id, date: shift.date))
        }
    }

    private var emptyHero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("hero.eyebrow.nextShift")
                .frText(FRType.eyebrow)
                .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.55))
            Text(LocalizedStringKey(schedule.isLoading ? "shifts.loading" : "shifts.none"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
            if let err = schedule.lastError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk.opacity(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: FRRadius.hero.value, style: .continuous).fill(Color.foodrun.foreground))
    }

    // MARK: - Mode pills

    private var modePills: some View {
        @Bindable var s = schedule
        return FRSegmentedPills(
            ScheduleStore.ShiftsMode.allCases,
            selection: $s.mode
        ) { m in
            switch m {
            case .shifts:       return "mode.shifts"
            case .roster:       return "mode.roster"
            case .availability: return "mode.availability"
            }
        }
    }

    // MARK: - Week carousel

    private var weekCarousel: some View {
        @Bindable var s = schedule
        let byDay = Dictionary(grouping: schedule.shifts, by: \.day)
        return FRWeekCarousel(
            selectedDate: $s.selectedDate,
            weekOffset: $s.weekOffset,
            monthOpen: $s.monthOpen,
            today: schedule.today,
            barColorFor: { d in
                let key = ScheduleStore.iso(d)
                if schedule.mode == .availability {
                    switch availability.stateFor(d) {
                    case .available:   return Color.foodrun.subject.positive
                    case .unavailable: return Color.foodrun.subject.destructive
                    case .unset:       return byDay[key] == nil ? nil : Color.foodrun.mutedForegroundSoft
                    }
                }
                return byDay[key]?.first.map { Color.foodrunData(hex: $0.activity.color) }
            },
            shiftCount: { d in byDay[ScheduleStore.iso(d)]?.count ?? 0 }
        )
    }

    // MARK: - Mode body

    @ViewBuilder
    private var modeBody: some View {
        switch schedule.mode {
        case .shifts:       ShiftsMode()
        case .roster:       RosterMode()
        case .availability: AvailabilityMode()
        }
    }

    // MARK: - Actions

    /// User tapped the dashed NFC listening strip. Opens Apple's scan sheet,
    /// then hands the tag link to ClockStore.handleTagRead; the server decides
    /// which shift it is for and whether it is a clock-in or a clock-out.
    private func armNFCReader(for shift: WorkerShift) {
        clock.activityId = shift.activity.id
        NFCReader.shared.start(hint: hintCopy()) { result in
            switch result {
            case .tag(_, let url):
                guard let url else {
                    clock.tagError = FRLanguage.string("clock.nfc.unreadable")
                    FRHaptic.warning.fire()
                    return
                }
                Task { await clock.handleTagRead(url: url) }
            case .cancelled:
                break
            case .error(let e):
                clock.tagError = e.localizedDescription
                FRHaptic.error.fire()
            case .unavailable:
                clock.tagError = FRLanguage.string("clock.nfc.unsupported")
                FRHaptic.error.fire()
            }
        }
    }

    private func hintCopy() -> String {
        FRLanguage.string(clock.clockedIn ? "clock.nfc.hintOut" : "clock.nfc.hintIn")
    }

    private func openTasksIfUnlocked(_ shift: WorkerShift) {
        if schedule.isToday(shift.date) && clock.clockedIn {
            router.tab = .tasks
        } else {
            router.pushOnShifts(.shiftDetail(activityId: shift.activity.id, date: shift.date))
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

#Preview {
    AppShell(preview: true).environmentObject(AuthViewModel())
}
