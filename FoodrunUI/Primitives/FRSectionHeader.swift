import SwiftUI

public struct FRSectionHeader: View {
    let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .font(Font.foodrun.sectionTitle)
            .foregroundStyle(Color.foodrun.mutedForeground)
            .textCase(.uppercase)
            .kerning(0.6)
            .padding(.horizontal, FRSpacing.lg.value)
            .padding(.top, FRSpacing.md.value)
            .padding(.bottom, FRSpacing.xs.value)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
