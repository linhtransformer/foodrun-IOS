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

    /// The phone can't read tags but the employer allows the button: confirm a clock without one.
    @State private var manualClockShift: WorkerShift?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                modePills
                if schedule.mode != .shifts {
                    weekCarousel
                }
                modeBody
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, 16)
        }
        // The next-shift card floats just above the tab bar, in thumb reach, and the page
        // starts with the pills. The inset also keeps the list's end clear of card and bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            hero
                .padding(.horizontal, FRSpacing.screenH.value)
                .padding(.top, 14)
                .padding(.bottom, Self.tabBarClearance)
                .background(
                    LinearGradient(colors: [Color.foodrun.background.opacity(0), Color.foodrun.background],
                                   startPoint: .top, endPoint: .init(x: 0.5, y: 0.25))
                        .ignoresSafeArea(edges: .bottom)
                        .allowsHitTesting(false)
                )
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable { await schedule.load() }
        .task(id: schedule.nextShift?.id) {
            // Refresh clocked-in state for the next shift — picks up events
            // written elsewhere (operator correcting a clock in HQ, another device).
            guard let shift = schedule.nextShift else { return }
            clock.activityId = shift.activity.id
            await clock.refreshLatestEvent(employeeId: shift.employee.id)
            await clock.loadClockRules(activityIds: [shift.activity.id])
        }
        .confirmationDialog(
            Text(clock.clockedIn ? "clock.confirmOut" : "clock.confirmIn"),
            isPresented: Binding(get: { manualClockShift != nil }, set: { if !$0 { manualClockShift = nil } }),
            titleVisibility: .visible,
            presenting: manualClockShift
        ) { shift in
            Button(clock.clockedIn ? "clock.out" : "clock.in") { clockWithoutTag(shift) }
        } message: { _ in
            Text("clock.noNFC.useButton")
        }
    }

    // MARK: - Hero

    /// From the bottom safe area to just above the floating tab bar (AppShell: 22pt from the
    /// screen edge, ~72pt tall) with a 10pt gap.
    private static let tabBarClearance: CGFloat = 70

    @ViewBuilder
    private var hero: some View {
        // Only on the day itself (or while still on the clock, e.g. past midnight): other
        // shifts are in the list below, revealed when they come up.
        if let shift = schedule.nextShift, schedule.isToday(shift.date) || clock.clockedIn {
            // `elapsed` is worked out from the clock-in time; redraw every second while on the
            // clock so the timer runs (paused otherwise — nothing to count).
            TimelineView(.animation(minimumInterval: 1, paused: !clock.clockedIn)) { _ in
                heroCard(shift)
            }
            // Its own height, not the space the bottom inset offers.
            .fixedSize(horizontal: false, vertical: true)
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
            checklistProgress: (tasks.completed, tasks.items.count),
            canClock: schedule.isToday(shift.date) && !shift.isAtFormerEmployer,
            clockInTime: clock.clockInAt.map(Self.hhmm),
            remaining: shift.endsAt.timeIntervalSinceNow
        )
        .onTapGesture {
            // Whole card opens detail (bundle §Next-shift hero).
            router.pushOnShifts(.shiftDetail(activityId: shift.activity.id, date: shift.date))
        }
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
                    // Grey: there is work that day (rostered or opened for availability), not filled in yet.
                    case .unset:
                        return byDay[key] == nil && schedule.activitiesRunning(on: key).isEmpty
                            ? nil : Color.foodrun.mutedForegroundSoft
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
                clock.tagError = ClockStore.readerMessage(for: e)
                FRHaptic.error.fire()
            case .unavailable:
                // No NFC on this phone: offer the button when the employer allows it.
                if clock.allowsButton(for: shift.activity.id) {
                    manualClockShift = shift
                } else {
                    clock.tagError = FRLanguage.string("clock.nfc.unsupported")
                    FRHaptic.error.fire()
                }
            }
        }
    }

    /// Same RPCs as the shift screen's "Klok in" button. This page has no error line, so a
    /// refusal is shown as the clock alert.
    private func clockWithoutTag(_ shift: WorkerShift) {
        clock.activityId = shift.activity.id
        Task {
            await clock.toggleManually()
            if let error = clock.lastError {
                clock.tagError = error
                clock.lastError = nil
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

    private static func hhmm(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
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
