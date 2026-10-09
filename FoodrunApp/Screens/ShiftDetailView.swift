import SwiftUI

// Bundle §3 "Shift detail", briefing-first (HQ decision 0038). Opening a shift
// shows the event straight away, in three tabs:
//   Draaiboek — what the script portal shows: the day's note, my day + tickets,
//               what we sell, event details, locations, run-of-show, links,
//               files, team. Read-only.
//   Setup     — build-up and teardown.
//   Taken     — the prep checklist and stock count as tasks, plus the
//               operator's tasks.
// What each person sees is set in HQ → Activity → Crew-app (get_my_event).

public enum ShiftTab: String, CaseIterable, Identifiable {
    case briefing, setup, tasks
    public var id: String { rawValue }
}

public struct ShiftDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TabRouter.self) private var router
    @Environment(ClockStore.self) private var clock
    @Environment(TasksStore.self) private var tasks
    @Environment(ScheduleStore.self) private var schedule
    @Environment(HoursStore.self) private var hours
    @Environment(ShiftChangeStore.self) private var changes
    @Environment(\.openURL) private var openURL

    public let activityId: UUID
    public let date: Date

    @State private var store: EventStore
    @State private var tab: ShiftTab
    @State private var day: String
    @State private var openDish: CrewDish?
    @State private var answering: CrewTask?
    @State private var showPrep = false
    @State private var showStock = false

    public init(activityId: UUID, date: Date, startOn tab: ShiftTab = .briefing) {
        self.activityId = activityId
        self.date = date
        _store = State(initialValue: EventStore(activityId: activityId))
        _tab = State(initialValue: tab)
        _day = State(initialValue: SchemaDates.string(date))
    }

    /// The rostered shift this screen shows (activity × day), from ScheduleStore.
    private var shift: WorkerShift? { schedule.shift(activityId: activityId, day: SchemaDates.string(date)) }
    private var activity: DBActivity? { shift?.activity ?? schedule.activities.first { $0.id == activityId } }

    /// Summary card starts folded (like the Shifts hero) so the tabs sit high.
    @State private var summaryExpanded = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryCard
                if AppConfig.Features.crewTasks {
                    crewContent
                } else {
                    nfcStrip
                    locationCard
                    crewSection
                }
                if AppConfig.Features.checklists { gateCard }
                if AppConfig.Features.shiftSwaps { requestSwap }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, 8)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        // Hide the whole (empty) bar too, or it pushes the custom header down.
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { if AppConfig.Features.crewTasks { await store.load() } }
        .task {
            guard AppConfig.Features.crewTasks else { return }
            await store.load()
            settleDay()
        }
        // Seeing the shift counts as seeing the change.
        .onAppear { changes.markRead(activityId: activityId, day: SchemaDates.string(date)) }
        .sheet(item: $openDish) { dish in CrewDishSheet(dish: dish) }
        .sheet(item: $answering) { task in answerSheet(for: task) }
        .sheet(isPresented: $showPrep) { CrewPrepListSheet(store: store) }
        .sheet(isPresented: $showStock) { CrewStockListSheet(store: store, day: day) }
    }

    /// Back arrow with the festival name next to it (truck · location below).
    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: store.event?.activity.name ?? activity?.name ?? "")
                    .font(.system(size: 20, weight: .bold)).tracking(-0.4)
                    .lineLimit(2)
                let sub = [store.event?.activity.food_truck ?? activity?.food_truck,
                           store.event?.activity.location ?? activity?.location].compactMap { $0 }.joined(separator: " · ")
                if !sub.isEmpty {
                    HStack(spacing: 6) {
                        Circle().fill(Color.foodrunData(hex: activity?.color)).frame(width: 7, height: 7)
                        Text(verbatim: sub).lineLimit(1)
                    }
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Briefing / Setup / Taken

    @ViewBuilder
    private var crewContent: some View {
        if let event = store.event {
            tabPicker(event)
            nfcStrip
            if event.my_days.count > 1 && tab != .setup { dayPicker(event) }
            if let error = store.lastError { errorLine(error) }
            switch tab {
            case .briefing:
                ShiftBriefingContent(event: event, day: day, onOpenDish: { openDish = $0 })
            case .setup:
                ShiftSetupContent(briefing: event.briefing)
            case .tasks:
                if event.activity.is_closed { closedLine }
                ShiftTasksContent(store: store, event: event, day: day,
                                  onOpenDish: { openDish = $0 },
                                  onAnswer: { answering = $0 },
                                  onOpenPrep: { showPrep = true },
                                  onOpenStock: { showStock = true })
            }
        } else if store.isLoading {
            nfcStrip
            ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
        } else {
            nfcStrip
            locationCard
            if let error = store.lastError { errorLine(error) }
        }
    }

    private func tabPicker(_ event: CrewEvent) -> some View {
        let open = openCount(event)
        return HStack(spacing: 4) {
            ForEach(ShiftTab.allCases) { t in
                let active = t == tab
                Button {
                    withAnimation(FRAnimation.subtle) { tab = t }
                    FRHaptic.light.fire()
                } label: {
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey(tabKey(t)))
                        if t == .tasks && open > 0 {
                            Text(verbatim: "\(open)")
                                .font(.system(size: 11, weight: .bold).monospacedDigit())
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(active ? Color.foodrun.backgroundInverseInk.opacity(0.2) : Color.foodrun.neuTrack))
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Capsule().fill(active ? Color.foodrun.foreground : Color.foodrun.card.opacity(0)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Color.foodrun.card))
        .frNeu(.raised)
    }

    private func tabKey(_ t: ShiftTab) -> String {
        switch t {
        case .briefing: return "shift.tab.briefing"
        case .setup: return "shift.tab.setup"
        case .tasks: return "shift.tab.tasks"
        }
    }

    /// Open items on the selected day: operator tasks, plus the prep list and
    /// the stock count while they aren't finished.
    private func openCount(_ event: CrewEvent) -> Int {
        var n = store.tasks(on: day).filter { store.response(for: $0, on: day)?.done != true }.count
        if let items = event.prep?.items, items.contains(where: { !$0.checked }) { n += 1 }
        if let products = event.stock?.products,
           products.contains(where: { store.myCount(productId: $0.product_id, on: day) == nil }) { n += 1 }
        return n
    }

    private func dayPicker(_ event: CrewEvent) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(event.my_days, id: \.self) { d in
                    let active = d == day
                    Button {
                        day = d
                        FRHaptic.light.fire()
                    } label: {
                        Text(verbatim: CrewFormat.day(d))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(active ? Color.foodrun.backgroundInverseInk : Color.foodrun.foreground)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Capsule().fill(active ? Color.foodrun.foreground : Color.foodrun.card))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Open on the shift's own day when it's one of my days, else the first
    /// upcoming one.
    private func settleDay() {
        guard let event = store.event, !event.my_days.contains(day) else { return }
        let today = SchemaDates.string(Date())
        day = event.my_days.first { $0 >= today } ?? event.my_days.first ?? day
    }

    private var closedLine: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock")
            Text("crew.event.closed")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
    }

    private func errorLine(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
            Text(verbatim: text)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.foodrun.subject.destructive)
    }

    @ViewBuilder
    private func answerSheet(for task: CrewTask) -> some View {
        let current = store.response(for: task, on: day)
        if task.kind == .photo {
            CrewPhotoSheet(
                title: task.title,
                prompt: task.instructions,
                existingPath: current?.photo_path,
                onSave: { jpeg in await store.answerPhoto(task, on: day, jpeg: jpeg) },
                onClear: { await store.answer(task, on: day, done: false) }
            )
        } else {
            CrewAnswerSheet(
                title: task.title,
                prompt: task.instructions,
                kind: task.kind,
                units: task.unit.map { [$0] } ?? [],
                initialNumber: current?.value_number,
                initialText: current?.value_text,
                initialUnitLevel: 0,
                canClear: current != nil,
                onSave: { number, text, _ in
                    await store.answer(task, on: day, done: true, number: number, text: text)
                },
                onClear: { await store.answer(task, on: day, done: false) }
            )
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

        return ZStack(alignment: .topTrailing) {
            Group {
                if summaryExpanded {
                    summaryExpandedBody(ink: ink, sub: sub, statusFill: statusFill, statusInk: statusInk, divider: divider)
                        .padding(18)
                } else {
                    summaryCollapsedBody(ink: ink, sub: sub, statusFill: statusFill, statusInk: statusInk)
                        .padding(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 44))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Same toggle as the Shifts hero (FRNextShiftCard).
            Button {
                withAnimation(FRAnimation.subtle) { summaryExpanded.toggle() }
                FRHaptic.light.fire()
            } label: {
                Image(systemName: summaryExpanded ? "minus" : "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ink)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(ink.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .padding(10)
            .accessibilityLabel(Text(summaryExpanded ? "hero.collapse" : "hero.expand"))
        }
        .background(
            RoundedRectangle(cornerRadius: FRRadius.hero.value, style: .continuous)
                .fill(isTodayShift ? Color.foodrun.foreground : Color.foodrun.card)
        )
        .shadow(color: .black.opacity(isTodayShift ? 0.22 : 0), radius: isTodayShift ? 14 : 0, y: isTodayShift ? 8 : 0)
        .modifier(SummaryCardNeu(applyNeu: !isTodayShift))
    }

    /// Folded: truck + status, then "10:00 – 18:00  do · Kitchen".
    private func summaryCollapsedBody(ink: Color, sub: Color, statusFill: Color, statusInk: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Circle().fill(Color.foodrunData(hex: activity?.color)).frame(width: 6, height: 6)
                Text(verbatim: activity?.food_truck ?? activity?.name ?? "")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ink.opacity(0.85))
                    .lineLimit(1)
                Text("detail.status.confirmed")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(statusFill))
                    .foregroundStyle(statusInk)
            }
            HStack(spacing: 8) {
                Text(verbatim: "\(shift?.start ?? "--:--") – \(shift?.end ?? "--:--")")
                    .font(.system(size: 20, weight: .heavy).monospacedDigit())
                    .tracking(-0.4)
                    .foregroundStyle(ink)
                Text(verbatim: [shortDay, shift?.employee.roles?.first].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(sub)
                    .lineLimit(1)
            }
        }
    }

    private var shortDay: String {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; f.locale = FRLanguage.locale
        return f.string(from: date)
    }

    private func summaryExpandedBody(ink: Color, sub: Color, statusFill: Color, statusInk: Color, divider: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
