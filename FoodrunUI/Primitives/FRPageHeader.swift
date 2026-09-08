import SwiftUI

// The single H1 per screen. Not a NavigationTitle — a custom scroll-collapsing
// header so we control typography exactly (SF Pro Display Semibold, tight tracking).

public struct FRPageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String?
    let backAction: (() -> Void)?
    @ViewBuilder let trailing: () -> Trailing

    public init(
        title: String,
        subtitle: String? = nil,
        backAction: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.backAction = backAction
        self.trailing = trailing
    }

    public var body: some View {
        HStack(alignment: .top, spacing: FRSpacing.md.value) {
            if let backAction {
                Button(action: backAction) {
                    Image(systemName: "chevron.backward")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .pressable()
                .offset(x: -8)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Font.foodrun.pageTitle)
                    .tracking(-0.5)
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
        .padding(.top, FRSpacing.md.value)
        .padding(.bottom, FRSpacing.md.value)
    }
}
