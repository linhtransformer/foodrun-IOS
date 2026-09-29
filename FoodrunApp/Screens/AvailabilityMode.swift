import SwiftUI

// Bundle §2c "Availability mode".

struct AvailabilityMode: View {
    @Environment(ScheduleStore.self) private var schedule
    @Environment(AvailabilityStore.self) private var availability

    var body: some View {
        @Bindable var av = availability
        VStack(spacing: 14) {
            FRStepperRow("availability.wantThisWeek", value: $av.wantShifts)
            FRStepperRow("availability.standardPerWeek", value: $av.standardShifts)

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

            legendAndCloses
            agentNote
            saveWeek
        }
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
            Text("availability.closesThu")
                .frText(FRType.fieldLabel)
                .foregroundStyle(Color.foodrun.foreground)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.foodrun.subject.warningPill))
        }
    }

    private var agentNote: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundStyle(Color.foodrun.foreground)
            Text("availability.agent \(3) \(4)")
                .font(.system(size: 12.5))
                .foregroundStyle(Color.foodrun.foreground)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.foodrun.truck.mees.opacity(0.3))
        )
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
