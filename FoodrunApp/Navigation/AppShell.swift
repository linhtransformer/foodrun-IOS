import SwiftUI

// Post-auth root. Hosts the floating tab bar + per-tab NavigationStack.

public struct AppShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router: TabRouter
    @State private var schedule: ScheduleStore
    @State private var clock: ClockStore
    @State private var availability: AvailabilityStore
    @State private var hours: HoursStore
    @State private var tasks: TasksStore
    @State private var inbox: InboxStore
    @State private var changes = ShiftChangeStore()
    /// Operator-assigned tasks (Tasks tab) — get_my_crew_tasks.
    @State private var crewTasks = CrewTasksStore()
    /// Ruilen (get_my_swap_board) and Verlof (leave_requests).
    @State private var swaps = SwapStore()
    @State private var leave = LeaveStore()
    private let isPreview: Bool

    /// Signed-in app: empty stores filled from Supabase (the same tables HQ uses).
    /// `preview: true` swaps in Fixtures for #Preview / the design mirror.
    public init(preview: Bool = false, router: TabRouter? = nil) {
        isPreview = preview
        _router = State(initialValue: router ?? TabRouter())
        _schedule = State(initialValue: preview ? ScheduleStore.preview : ScheduleStore())
        _clock = State(initialValue: preview ? ClockStore.preview : ClockStore())
        _availability = State(initialValue: preview ? AvailabilityStore.preview : AvailabilityStore())
        _hours = State(initialValue: preview ? HoursStore.preview : HoursStore())
        // Checklists stay off until tasks RLS lets workers read their assigned
        // tasks (see SchemaContract.md → TasksStore) — sample data must never
        // reach real users.
        _tasks = State(initialValue: preview || AppConfig.Features.checklists ? TasksStore.preview : TasksStore())
        _inbox = State(initialValue: preview ? InboxStore.preview : InboxStore())
    }

    /// Pull everything the worker sees. Runs on sign-in and each time the app
    /// returns to the foreground, so approvals/roster edits made in HQ show up.
    private func clockWithScannedTag() async {
        guard !isPreview, let token = ScannedClockTag.shared.take() else { return }
        await clock.clockWithTag(token: token)
    }

    private func loadAll() async {
        guard !isPreview else { return }
        await schedule.load()
        if schedule.rosterLoaded, let uid = try? await WorkerAPI.currentUserId() {
            changes.track(schedule.shifts, today: SchemaDates.string(schedule.today), userId: uid)
        }
        let ids = schedule.employees.map(\.id)
        // Hours include a former employer's (history); availability never does.
        async let h: Void = hours.load(employeeIds: schedule.historyEmployeeIds)
        async let a: Void = availability.load(employeeIds: ids)
        async let i: Void = inbox.load()
        async let t: Void = crewTasks.load()
        async let s: Void = swaps.load()
        _ = await (h, a, i, t, s)
    }

    /// Tabs shown in the bar — Tasks when operator tasks (or the old sample
    /// checklist) are switched on.
    private var visibleTabs: [FRTab] {
        FRTab.allCases.filter { $0 != .tasks || isPreview || AppConfig.Features.crewTasks || AppConfig.Features.checklists }
    }

    /// Real operator tasks unless this is a preview of the design fixtures.
    private var showsCrewTasks: Bool { AppConfig.Features.crewTasks && !isPreview }

    public var body: some View {
        Group {
            if schedule.isUnlinked {
                // Account exists but no employer has added it yet.
                NotLinkedView(onRefresh: loadAll)
            } else {
                ZStack(alignment: .bottom) {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.foodrun.background.ignoresSafeArea())
                        // Opaque strip behind the status bar: the screens hide their nav
                        // bars, so scrolled content otherwise runs under the clock.
                        .safeAreaInset(edge: .top, spacing: 0) {
                            Color.clear.frame(height: 0).background(Color.foodrun.background)
                        }

                    FRTabBar(
                        selection: Binding(
                            get: { router.tab },
                            set: { router.tab = $0 }
                        ),
                        tabs: visibleTabs,
                        badgedTabs: badges
                    )
                    // Measured from the screen edge, not the safe area, so the bar sits
                    // just above the home indicator instead of floating 56pt up.
                    .padding(.bottom, 22)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea(.container, edges: .bottom)
                }
            }
        }
        .task { await loadAll() }
        .task { await ShiftChangeStore.requestAuthorization() }
        // A clock tag scanned with the app closed, in the background or before
        // signing in: clock as soon as a signed-in shell is on screen.
        .task(id: ScannedClockTag.shared.token) { await clockWithScannedTag() }
        // Accepted an email invite: the new employer's shifts show at once.
        .onChange(of: PendingInvite.shared.joinedAt) { _, _ in Task { await loadAll() } }
        .alert(
            Text("clock.tag.alertTitle"),
            isPresented: Binding(get: { clock.tagError != nil }, set: { if !$0 { clock.tagError = nil } })
        ) {
            Button("action.ok", role: .cancel) { clock.tagError = nil }
        } message: {
            Text(verbatim: clock.tagError ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadAll() } }
        }
        .onChange(of: clock.nfcResult) { _, result in
            // A clock-out usually means hours are due — refresh so the Hours tab
            // shows the "Waiting for you" card straight away.
            if result == .clockedOut { Task { await hours.load(employeeIds: schedule.historyEmployeeIds) } }
        }
        .environment(router)
        .environment(schedule)
        .environment(clock)
        .environment(availability)
        .environment(hours)
        .environment(tasks)
        .environment(inbox)
        .environment(changes)
        .environment(crewTasks)
        .environment(swaps)
        .environment(leave)
        .sheet(isPresented: Binding(
            get: { router.addShiftOpen },
            set: { router.addShiftOpen = $0 }
        )) {
            AddShiftSheet()
                .environment(router)
                .environment(schedule)
        }
        .overlay(alignment: .bottom) {
            if clock.nfcResult != .none {
                NFCResultSheet(
                    result: clock.nfcResult,
                    clockInTime: formatted(clock.clockInAt),
                    truckName: clock.lastTagActivityName
                        ?? schedule.nextShift.map { $0.activity.food_truck ?? $0.activity.name } ?? "",
                    worked: workedLabel, span: spanLabel,
                    checklistsEnabled: isPreview || AppConfig.Features.checklists,
                    onOpenChecklist: {
                        // Primary button: clock-in → checklist (or just close when
                        // checklists are off); clock-out → "Review my hours".
                        let result = clock.nfcResult
                        clock.acknowledgeNFC()
                        if result == .clockedOut {
                            router.tab = .hours
                        } else if isPreview || AppConfig.Features.checklists {
                            router.tab = .tasks
                        }
                    },
                    onDismissUndo: { clock.acknowledgeNFC() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(FRAnimation.nfcResultRise, value: clock.nfcResult)
    }

    @ViewBuilder
    private var content: some View {
        switch router.tab {
        case .shifts:
            NavigationStack(path: Binding(get: { router.shiftsPath }, set: { router.shiftsPath = $0 })) {
                ShiftsView()
                    .navigationDestination(for: TabRouter.Route.self, destination: destination)
            }
        case .tasks:
            NavigationStack(path: Binding(get: { router.tasksPath }, set: { router.tasksPath = $0 })) {
                Group {
                    if showsCrewTasks { CrewTasksView() } else { TasksView() }
                }
                .navigationDestination(for: TabRouter.Route.self, destination: destination)
            }
        case .hours:
            NavigationStack(path: Binding(get: { router.hoursPath }, set: { router.hoursPath = $0 })) {
                HoursView()
                    .navigationDestination(for: TabRouter.Route.self, destination: destination)
            }
        case .inbox:
            NavigationStack(path: Binding(get: { router.inboxPath }, set: { router.inboxPath = $0 })) {
                InboxView()
                    .navigationDestination(for: TabRouter.Route.self, destination: destination)
            }
        case .me:
            NavigationStack(path: Binding(get: { router.mePath }, set: { router.mePath = $0 })) {
                ProfileView()
                    .navigationDestination(for: TabRouter.Route.self, destination: destination)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: TabRouter.Route) -> some View {
        switch route {
        case .shiftDetail(let activityId, let date):
            ShiftDetailView(activityId: activityId, date: date)
        case .event(let activityId, let date):
            ShiftDetailView(activityId: activityId, date: date, startOn: .tasks)
        case .tasks:
            if showsCrewTasks { CrewTasksView() } else { TasksView() }
        case .approvedHours:
            ApprovedHoursView()
        case .swaps:
            SwapsView()
        case .leave:
            LeaveView()
        }
    }

    private var badges: Set<FRTab> {
        var s: Set<FRTab> = []
        if hours.pendingRow != nil { s.insert(.hours) }
        if inbox.unreadCount + changes.unreadCount > 0 || (AppConfig.Features.shiftSwaps && swaps.attentionCount > 0) { s.insert(.inbox) }
        if showsCrewTasks && crewTasks.openCount(on: SchemaDates.string(Date())) > 0 { s.insert(.tasks) }
        return s
    }

    /// "4 u 12 min" between the last clock-in and clock-out.
    private var workedLabel: String? {
        guard let start = clock.clockInAt, let end = clock.clockOutAt, end > start else { return nil }
        let f = DateComponentsFormatter()
        f.allowedUnits = [.hour, .minute]
        f.unitsStyle = .abbreviated
        var cal = Calendar.current; cal.locale = FRLanguage.locale
        f.calendar = cal
        return f.string(from: max(60, end.timeIntervalSince(start)))
    }

    /// "19:02 – 23:14".
    private var spanLabel: String? {
        guard let start = clock.clockInAt, let end = clock.clockOutAt, end > start else { return nil }
        return "\(formatted(start)) – \(formatted(end))"
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
    }
}
