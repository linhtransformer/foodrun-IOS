import SwiftUI

// Bundle §7. Inbox.

public struct InboxView: View {
    @Environment(InboxStore.self) private var inbox

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if inbox.items.isEmpty {
                    Text("inbox.empty")
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                }
                ForEach(inbox.items) { item in
                    row(item)
                        .onTapGesture { inbox.markRead(item.id) }
                }
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .refreshable { await inbox.load() }
    }

    private func row(_ item: DBWorkerNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            agentAvatar(item)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title).frText(FRType.rowTitle)
                    Spacer()
                    Text(relative(item.created_at))
                        .frText(FRType.rowSubtitle)
                        .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    if !item.is_read {
                        Circle().fill(Color.foodrun.subject.warning).frame(width: 8, height: 8)
                    }
                }
                if let body = item.body {
                    Text(body).font(.system(size: 12.5)).foregroundStyle(Color.foodrun.foreground)
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

    private func agentAvatar(_ item: DBWorkerNotification) -> some View {
        // System notices (roster changes) get the Foodrun mark; decisions by a person
        // (hours approved/rejected, join approved) get the operator's initials.
        let isAgent = item.type == .activity_added || item.type == .activity_updated || item.type == .other
        return Group {
            if isAgent {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.foodrun.foreground)
                    .frame(width: 36, height: 36)
                    .overlay(Text("F").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color.foodrun.backgroundInverseInk))
            } else {
                Circle()
                    .fill(Color.foodrun.truck.mees)
                    .frame(width: 36, height: 36)
                    .overlay(Text(verbatim: initials(item.operator_name)).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.foodrun.foreground))
            }
        }
    }

    private func initials(_ name: String?) -> String {
        let parts = (name ?? "Foodrun").split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    private func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter(); f.locale = FRLanguage.locale; f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
