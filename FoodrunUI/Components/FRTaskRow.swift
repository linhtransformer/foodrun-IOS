import SwiftUI

// Bundle §4 "Tasks / checklist" row.
// 24pt rounded checkbox + title + note + optional value/photo chip.

public struct FRTaskRow: View {
    public let title: String
    public let note: String?
    public let completed: Bool
    public let completedAt: Date?
    public let value: String?               // e.g. "3,2 °C"
    public let requiresPhoto: Bool
    public var onToggle: () -> Void
    public var onSetValue: (() -> Void)?
    public var onPickPhoto: (() -> Void)?

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: {
                onToggle(); FRHaptic.success.fire()
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(completed ? Color.foodrun.foreground : Color.foodrun.background)
                        .frame(width: 24, height: 24)
                    if completed {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    }
                }
                .frNeu(completed ? .raised : .pressed)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(completed ? "task.done" : "task.todo"))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14.5, weight: .semibold))
                    .strikethrough(completed)
                    .foregroundStyle(Color.foodrun.foreground)
                if let note {
                    Text(note)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                if !completed {
                    HStack(spacing: 6) {
                        if let onSetValue {
                            Button(action: onSetValue) {
                                Text(value ?? "task.enterValue")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.foodrun.foreground)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(
                                        Capsule().fill(Color.foodrun.background)
                                    )
                                    .frNeu(.pressed)
                            }
                            .buttonStyle(.plain)
                        }
                        if requiresPhoto, let onPickPhoto {
                            Button(action: onPickPhoto) {
                                HStack(spacing: 4) {
                                    Image(systemName: "camera")
                                    Text("task.photo")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.foodrun.foreground)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .overlay(
                                    Capsule().strokeBorder(
                                        Color.foodrun.mutedForegroundSoft.opacity(0.5),
                                        style: StrokeStyle(lineWidth: 1, dash: [3])
                                    )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                if let completedAt {
                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .frNeu(.raised)
        .opacity(completed ? 0.55 : 1)
    }
}

#Preview("Task row") {
    VStack(spacing: 10) {
        FRTaskRow(title: "Prep station ready", note: "Wipe surface, stock cutlery.",
                  completed: false, completedAt: nil, value: nil, requiresPhoto: false,
                  onToggle: {})
        FRTaskRow(title: "Fridge temperature", note: "Log ≤ 4,0 °C.",
                  completed: true, completedAt: Date(), value: "3,2 °C",
                  requiresPhoto: false, onToggle: {})
    }
    .padding(20).background(Color.foodrun.background)
}
