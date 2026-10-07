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
    private func loadAll() async {
        guard !isPreview else { return }
        await schedule.load()
        if schedule.rosterLoaded, let uid = try? await WorkerAPI.currentUserId() {
            changes.track(schedule.shifts, today: SchemaDates.string(schedule.today), userId: uid)
        }
        let ids = schedule.employees.map(\.id)
        async let h: Void = hours.load(employeeIds: ids)
        async let a: Void = availability.load(employeeIds: ids)
        async let i: Void = inbox.load()
        _ = await (h, a, i)
    }

    /// Tabs shown in the bar — Tasks only when checklists are switched on.
    private var visibleTabs: [FRTab] {
        FRTab.allCases.filter { $0 != .tasks || isPreview || AppConfig.Features.checklists }
    }

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await loadAll() } }
        }
        .onChange(of: clock.nfcResult) { _, result in
            // A clock-out usually means hours are due — refresh so the Hours tab
            // shows the "Waiting for you" card straight away.
            if result == .clockedOut { Task { await hours.load(employeeIds: schedule.employees.map(\.id)) } }
        }
        .environment(router)
        .environment(schedule)
        .environment(clock)
        .environment(availability)
        .environment(hours)
        .environment(tasks)
        .environment(inbox)
        .environment(changes)
        .sheet(isPresented: Binding(
            get: { router.swapSheetOpen },
            set: { router.swapSheetOpen = $0 }
        )) {
            SwapSheet()
                .environment(router)
                .presentationDetents([.fraction(0.6), .large])
                .presentationDragIndicator(.visible)
        }
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
                    truckName: schedule.nextShift.map { $0.activity.food_truck ?? $0.activity.name } ?? "",
                    worked: nil, span: nil,
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
                TasksView()
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
        case .tasks:
            TasksView()
        case .approvedHours:
            ApprovedHoursView()
        }
    }

    private var badges: Set<FRTab> {
        var s: Set<FRTab> = []
        if hours.pendingRow != nil { s.insert(.hours) }
        if inbox.unreadCount + changes.unreadCount > 0 { s.insert(.inbox) }
        return s
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
    }
}
