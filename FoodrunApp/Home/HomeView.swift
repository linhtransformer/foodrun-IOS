import SwiftUI

// Post-auth landing: the design-system showcase. Every primitive rendered
// so you can eyeball the visual language on-device. Replace with the real
// worker home ("Diensten") once project C starts.

struct HomeView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FRPageHeader(
                    title: "Foodrun",
                    subtitle: heroSubtitle
                ) {
                    Button {
                        Task { await auth.signOut() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Color.foodrun.foreground)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .pressable()
                }

                nextShiftHero
                    .padding(.horizontal, FRSpacing.lg.value)
                    .padding(.top, FRSpacing.sm.value)

                weekStrip
                    .padding(.top, FRSpacing.lg.value)

                FRSectionHeader("Deze week")
                shiftList
                    .padding(.horizontal, FRSpacing.lg.value)

                FRSectionHeader("Snelle acties")
                quickActions
                    .padding(.horizontal, FRSpacing.lg.value)

                FRSectionHeader("Design system")
                designSystemGallery
                    .padding(.horizontal, FRSpacing.lg.value)

                Spacer(minLength: FRSpacing.xxl.value)
            }
        }
        .background(Color.foodrun.background.ignoresSafeArea())
    }

    private var heroSubtitle: String {
        if case .signedIn(let email) = auth.state { return email }
        return ""
    }

    private var nextShiftHero: some View {
        FRCard(onTap: {}) {
            VStack(alignment: .leading, spacing: FRSpacing.md.value) {
                HStack {
                    FRStatusBadge(tone: .orders, label: "Volgende dienst")
                    Spacer()
                    Text("Woensdag")
                        .font(Font.foodrun.caption)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                }

                HStack(alignment: .firstTextBaseline, spacing: FRSpacing.sm.value) {
                    Text("19:00")
                        .font(.system(size: 44, weight: .bold, design: .default))
                        .tracking(-1.2)
                        .foregroundStyle(Color.foodrun.foreground)
                        .monospacedDigit()
                    Text("– 23:00")
                        .font(Font.foodrun.sectionTitle)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                }

                HStack(spacing: FRSpacing.sm.value) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.foodrun.mutedForeground)
                    Text("Vestiging Amsterdam Oost · Keuken")
                        .font(Font.foodrun.body)
                        .foregroundStyle(Color.foodrun.foreground)
                    Spacer()
                }
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: FRSpacing.xs.value) {
            ForEach(0..<7, id: \.self) { i in
                let hasShift = [1, 3, 5].contains(i)
                let isToday = i == 2
                VStack(spacing: 4) {
                    Text(dayName(i))
                        .font(Font.foodrun.caption)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                    ZStack {
                        Circle()
                            .fill(isToday ? Color.foodrun.foreground : Color.clear)
                            .frame(width: 32, height: 32)
                        Text("\(9 + i)")
                            .font(Font.foodrun.body.weight(isToday ? .semibold : .regular))
                            .foregroundStyle(isToday ? Color.foodrun.surface : Color.foodrun.foreground)
                    }
                    Circle()
                        .fill(hasShift ? Color.foodrun.subject.orders : .clear)
                        .frame(width: 5, height: 5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, FRSpacing.lg.value)
        .padding(.vertical, FRSpacing.md.value)
        .background(
            RoundedRectangle(cornerRadius: FRRadius.card.value, style: .continuous)
                .fill(Color.foodrun.surface)
        )
        .padding(.horizontal, FRSpacing.lg.value)
        .frElevation(.pop)
    }

    private var shiftList: some View {
        VStack(spacing: FRSpacing.sm.value) {
            shiftCard(day: "Ma 10 sep", time: "17:00 – 23:00", role: "Bediening", tone: .revenue, status: "Bevestigd")
            shiftCard(day: "Wo 12 sep", time: "19:00 – 23:00", role: "Keuken", tone: .orders, status: "Volgende")
            shiftCard(day: "Vr 14 sep", time: "12:00 – 18:00", role: "Bar", tone: .cash, status: "Wachten op ruil")
        }
    }

    private func shiftCard(day: String, time: String, role: String, tone: FRTone, status: String) -> some View {
        FRCard(onTap: {}) {
            HStack(alignment: .center, spacing: FRSpacing.md.value) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tone.ink)
                    .frame(width: 3, height: 44)
                VStack(alignment: .leading, spacing: 4) {
                    Text(day)
                        .font(Font.foodrun.caption)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                    Text(role)
                        .font(Font.foodrun.body.weight(.semibold))
                        .foregroundStyle(Color.foodrun.foreground)
                    Text(time)
                        .font(Font.foodrun.caption)
                        .foregroundStyle(Color.foodrun.mutedForeground)
                        .monospacedDigit()
                }
                Spacer()
                FRStatusBadge(tone: tone, label: status)
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: FRSpacing.sm.value) {
            FRRow(icon: "clock", title: "Uren indienen", subtitle: "1 dienst wacht op invoer", onTap: {}) {
                FRStatusBadge(tone: .alert, label: "1")
            }
            FRRow(icon: "calendar.badge.checkmark", title: "Beschikbaarheid", subtitle: "Volgende week openen", onTap: {}) {
                Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForeground)
            }
            FRRow(icon: "arrow.left.arrow.right", title: "Ruilaanvraag", subtitle: "Geen open aanvragen", onTap: {}) {
                Image(systemName: "chevron.right").foregroundStyle(Color.foodrun.mutedForeground)
            }
        }
    }

    private var designSystemGallery: some View {
        FRCard {
            VStack(alignment: .leading, spacing: FRSpacing.md.value) {
                Text("Onderwerpkleuren")
                    .font(Font.foodrun.sectionTitle)
                    .foregroundStyle(Color.foodrun.foreground)

                HStack(spacing: 6) {
                    ForEach([FRTone.revenue, .cost, .cash, .orders, .forecast, .alert, .info], id: \.self) { tone in
                        Circle().fill(tone.ink).frame(width: 24, height: 24)
                    }
                }

                Divider().background(Color.foodrun.border)

                Text("Statuspillen")
                    .font(Font.foodrun.sectionTitle)
                    .foregroundStyle(Color.foodrun.foreground)

                FlowRow(spacing: 6) {
                    FRStatusBadge(tone: .revenue, label: "Goedgekeurd")
                    FRStatusBadge(tone: .cost, label: "Afgewezen")
                    FRStatusBadge(tone: .alert, label: "In behandeling")
                    FRStatusBadge(tone: .orders, label: "Actief")
                    FRStatusBadge(tone: .neutral, label: "Concept")
                }

                Divider().background(Color.foodrun.border)

                Text("Knoppen")
                    .font(Font.foodrun.sectionTitle)
                    .foregroundStyle(Color.foodrun.foreground)

                FRPrimaryButton("Primaire actie") {}
                FRSecondaryButton("Secundair") {}
            }
        }
    }

    private func dayName(_ i: Int) -> String {
        ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"][i]
    }
}

// Simple flow layout wrapper (iOS 16+) — chips wrap to next line as needed.
struct FlowRow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .init(size))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    HomeView().environmentObject({
        let vm = AuthViewModel()
        return vm
    }())
}
