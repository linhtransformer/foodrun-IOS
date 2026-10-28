import SwiftUI

// Bundle §2c "Availability mode".

struct AvailabilityMode: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(AvailabilityStore.self) private var availability

    var body: some View {
        if schedule.employees.isEmpty && !schedule.formerEmployees.isEmpty {
            // Only employers the worker has left: nobody to give availability to.
            notice(Text("availability.formerOnly"), color: Color.foodrun.mutedForegroundSoft)
        } else {
            editor
        }
    }

    private var editor: some View {
        @Bindable var av = availability
        return VStack(spacing: 14) {
            FRStepperRow("availability.wantThisWeek", value: Binding(
                get: { av.wantShifts },
                set: { av.setWanted($0, weekOf: schedule.selectedDate) }
            ))
            FRStepperRow("availability.standardPerWeek", value: $av.standardShifts)

            if let work = workThatDay {
                notice(Text(verbatim: String(format: FRLanguage.string("availability.workThatDay %@"), work)),
                       color: Color.foodrun.mutedForegroundSoft)
            }

            if let org = availability.closedBy(schedule.selectedDate) {
                notice(Text("availability.closedBy \(org)"), color: Color.foodrun.subject.warning)
            }

            FRAvailabilityCard(
                date: schedule.selectedDate,
                window: Binding(
                    get: { av.windowFor(schedule.selectedDate) },
                    set: { av.setWindow($0, for: schedule.selectedDate) }
                ),
                state: Binding(
                    get: { av.stateFor(schedule.selectedDate) },
                    set: { av.setState($0, for: schedule.selectedDate) }
                ),
                reason: Binding(
                    get: { av.reasonFor(schedule.selectedDate) },
                    set: { av.setReason($0, for: schedule.selectedDate) }
                ),
                reasonRequired: availability.reasonRequired
            )
            .disabled(weekClosed)
            .opacity(weekClosed ? 0.55 : 1)

            if availability.reasonRequired && availability.stateFor(schedule.selectedDate) == .unavailable {
                notice(Text("availability.reasonRequired"), color: Color.foodrun.mutedForegroundSoft)
            }
            if let error = availability.lastError {
                notice(Text(verbatim: error), color: Color.foodrun.subject.destructive)
            }

            legendAndCloses
            saveWeek
        }
        // The wanted shifts belong to the week on screen.
        .task(id: AvailabilityStore.monday(of: schedule.selectedDate)) {
            await availability.loadWanted(employeeIds: schedule.employees.map(\.id), weekOf: schedule.selectedDate)
        }
    }

    private func notice(_ text: Text, color: Color) -> some View {
        text
            .frText(FRType.rowSubtitle)
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    /// "Festival, Kermis Utrecht" — what runs on the selected day, so a grey day reads as work.
    private var workThatDay: String? {
        let names = schedule.activitiesRunning(on: ScheduleStore.iso(schedule.selectedDate)).map(\.name)
        var seen = Set<String>()
        let unique = names.filter { seen.insert($0).inserted }
        return unique.isEmpty ? nil : unique.joined(separator: ", ")
    }

    /// The employer's deadline for this week has passed: the server refuses changes, so the
    /// page says so instead of letting the worker fill in a week that can't be saved.
    private var weekClosed: Bool {
        guard let at = availability.closesAt(weekOf: schedule.selectedDate) else { return false }
        return at < Date()
    }

    /// "Sluit do 18:00" — when the employer stops taking availability for this week.
    private var closesLabel: String? {
        guard let at = availability.closesAt(weekOf: schedule.selectedDate) else { return nil }
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "EEE d MMM HH:mm"
        return String(format: FRLanguage.string(at < Date() ? "availability.closedAt" : "availability.closesAt"),
                      f.string(from: at))
    }

    private var legendAndCloses: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                legendItem(Color.foodrun.subject.positive, "availability.legend.available")
                legendItem(Color.foodrun.subject.destructive, "availability.legend.notAvailable")
                legendItem(Color.foodrun.mutedForegroundSoft, "availability.legend.work")
                Spacer(minLength: 0)
            }
            if let closesLabel {
                Text(verbatim: closesLabel)
                    .frText(FRType.fieldLabel)
                    .foregroundStyle(Color.foodrun.foreground)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(weekClosed ? Color.foodrun.neuTrack : Color.foodrun.subject.warningPill))
            }
        }
    }

    private func legendItem(_ color: Color, _ key: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(key).frText(FRType.rowSubtitle).lineLimit(1)
        }
    }

    private var saveWeek: some View {
        Button {
            Task {
                if await availability.saveDirty(employeeIds: schedule.employees.map(\.id)) {
                    FRHaptic.success.fire()
                    withAnimation(FRAnimation.enter) { schedule.mode = .shifts }
                } else {
                    FRHaptic.error.fire()
                }
            }
        } label: {
            Text("availability.saveWeek \(Calendar(identifier: .iso8601).component(.weekOfYear, from: schedule.selectedDate))")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.foodrun.backgroundInverseInk)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(Color.foodrun.foreground))
                .frCTAShadow()
        }
        .buttonStyle(.plain)
        .disabled(availability.isSaving || weekClosed)
        .opacity(weekClosed ? 0.4 : 1)
    }
}
