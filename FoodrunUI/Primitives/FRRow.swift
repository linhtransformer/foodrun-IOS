import SwiftUI

// List row primitive. 44pt+ target (Apple HIG). Icon + title + subtitle + trailing.

public struct FRRow<Trailing: View>: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let onTap: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    @Environment(\.frHapticsEnabled) private var hapticsEnabled

    public init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.onTap = onTap
        self.trailing = trailing
    }

    public var body: some View {
        Group {
            if let onTap {
                Button(action: {
                    if hapticsEnabled { FRHaptic.light.fire() }
                    onTap()
                }) {
                    rowBody
                }
                .buttonStyle(.plain)
                .pressable()
            } else {
                rowBody
            }
        }
    }

    private var rowBody: some View {
        HStack(spacing: FRSpacing.md.value) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.foodrun.body)
                    .foregroundStyle(Color.foodrun.foreground)
                if let subtitle {
                    Text(subtitle)
                        .font(Font.foodrun.caption)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                }
            }
            Spacer()
            trailing()
        }
        .padding(.horizontal, FRSpacing.lg.value)
        .padding(.vertical, FRSpacing.md.value)
        .frame(minHeight: 52)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.row.value, style: .continuous)
                .fill(Color.foodrun.surface)
        )
    }
}

#Preview {
    VStack(spacing: 8) {
        FRRow(icon: "calendar", title: "Volgende dienst", subtitle: "Woensdag 19:00 – 23:00", onTap: {}) {
            Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForeground)
        }
        FRRow(icon: "clock", title: "Uren indienen", subtitle: "1 in behandeling") {
            Text("1").font(Font.foodrun.caption).padding(6).background(Circle().fill(Color.foodrun.subject.alert)).foregroundStyle(Color.foodrun.surface)
        }
    }
    .padding()
    .background(Color.foodrun.background)
}
