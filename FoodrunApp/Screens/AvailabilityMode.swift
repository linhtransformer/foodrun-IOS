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
                )
            )

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

    /// "Sluit do 18:00" — when the employer stops taking availability for this week.
    private var closesLabel: String? {
        guard let at = availability.closesAt(weekOf: schedule.selectedDate) else { return nil }
        let f = DateFormatter()
        f.locale = FRLanguage.locale
        f.timeZone = TimeZone(identifier: "Europe/Amsterdam")
        f.dateFormat = "EEE d MMM HH:mm"
        return String(format: FRLanguage.string("availability.closesAt"), f.string(from: at))
    }

    private var legendAndCloses: some View {
        HStack {
            HStack(spacing: 6) {
                Circle().fill(Color.foodrun.subject.positive).frame(width: 8, height: 8)
                Text("availability.legend.available")
                    .frText(FRType.rowSubtitle)
            }
            HStack(spacing: 6) {
                Circle().fill(Color.foodrun.subject.destructive).frame(width: 8, height: 8)
                Text("availability.legend.notAvailable")
                    .frText(FRType.rowSubtitle)
            }
            Spacer()
            if let closesLabel {
                Text(verbatim: closesLabel)
                    .frText(FRType.fieldLabel)
                    .foregroundStyle(Color.foodrun.foreground)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Color.foodrun.subject.warningPill))
            }
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
        .disabled(availability.isSaving)
    }
}
