import SwiftUI

// Post-auth root. Hosts the floating tab bar + per-tab NavigationStack.

public struct AppShell: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = TabRouter()
    @State private var schedule: ScheduleStore
    @State private var clock: ClockStore
    @State private var availability: AvailabilityStore
    @State private var hours: HoursStore
    @State private var tasks: TasksStore
    @State private var inbox: InboxStore
    private let isPreview: Bool

    /// Signed-in app: empty stores filled from Supabase (the same tables HQ uses).
    /// `preview: true` swaps in Fixtures for #Preview / the design mirror.
    public init(preview: Bool = false) {
        isPreview = preview
        _schedule = State(initialValue: preview ? ScheduleStore.preview : ScheduleStore())
        _clock = State(initialValue: preview ? ClockStore.preview : ClockStore())
        _availability = State(initialValue: preview ? AvailabilityStore.preview : AvailabilityStore())
        _hours = State(initialValue: preview ? HoursStore.preview : HoursStore())
        // Checklists stay local until tasks RLS lets workers read their assigned
        // tasks (see SchemaContract.md → TasksStore).
        _tasks = State(initialValue: TasksStore.preview)
        _inbox = State(initialValue: preview ? InboxStore.preview : InboxStore())
    }

    /// Pull everything the worker sees. Runs on sign-in and each time the app
    /// returns to the foreground, so approvals/roster edits made in HQ show up.
    private func loadAll() async {
        guard !isPreview else { return }
        await schedule.load()
        let ids = schedule.employees.map(\.id)
        async let h: Void = hours.load(employeeIds: ids)
        async let a: Void = availability.load(employeeIds: ids)
        async let i: Void = inbox.load()
        _ = await (h, a, i)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.foodrun.background.ignoresSafeArea())

            FRTabBar(
                selection: Binding(
                    get: { router.tab },
                    set: { router.tab = $0 }
                ),
                badgedTabs: badges
            )
            // Measured from the screen edge, not the safe area, so the bar sits
            // just above the home indicator instead of floating 56pt up.
            .padding(.bottom, 22)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .task { await loadAll() }
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
                    onOpenChecklist: {
                        clock.acknowledgeNFC()
                        router.tab = .tasks
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
        if inbox.unreadCount > 0 { s.insert(.inbox) }
        return s
    }

    private func formatted(_ date: Date?) -> String {
        guard let date else { return "-" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"; f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        return f.string(from: date)
    }
}
