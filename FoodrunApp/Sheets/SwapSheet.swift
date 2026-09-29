import SwiftUI

// Bundle §Sheets — "Swap sheet".

public struct SwapSheet: View {
    @Environment(TabRouter.self) private var router
    @State private var selected: Int = 1

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Capsule().fill(Color.foodrun.border).frame(width: 40, height: 4).frame(maxWidth: .infinity)
            Text("swap.title").frText(FRType.sectionHeader)
            Text("swap.context")
                .frText(FRType.rowSubtitle)
                .foregroundStyle(Color.foodrun.mutedForegroundSoft)

            ForEach(0..<3) { i in
                candidateRow(index: i)
            }

            Button {
                FRHaptic.success.fire()
                router.swapSheetOpen = false
            } label: {
                Text("swap.send")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.foodrun.backgroundInverseInk)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Capsule().fill(Color.foodrun.foreground))
                    .frCTAShadow()
            }.buttonStyle(.plain)

            Button {} label: {
                Text("swap.askCrew").frText(FRType.rowSubtitle)
            }.buttonStyle(.plain)
                .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(Color.foodrun.background.ignoresSafeArea(edges: .bottom))
    }

    private func candidateRow(index: Int) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Color.foodrun.truck.mama).frame(width: 36, height: 36)
                .overlay(Text("JK").font(.system(size: 13, weight: .semibold)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Julia K.").frText(FRType.rowTitle)
                Text("swap.available.body").frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            Spacer()
            if selected == index {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.foodrun.foreground)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .fill(Color.foodrun.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous)
                .stroke(selected == index ? Color.foodrun.foreground : .clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { selected = index }
    }
}
