import SwiftUI
import UserNotifications

// Ik → Instellingen: how the app looks and behaves on this phone, and deleting the account.
// Everything here is stored on the phone, except deleting (edge fn delete-my-account).

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthViewModel

    @AppStorage(FRAppearance.storageKey) private var appearance = FRAppearance.system.rawValue
    @AppStorage(ShiftChangeStore.notificationsKey) private var shiftNotifications = true
    @AppStorage(FRLanguage.storageKey) private var language = FRLanguage.system.rawValue
    /// What iOS allows: nil while unknown.
    @State private var systemAllowed: Bool?
    @State private var confirmDelete = false
    @State private var deleteFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                section("settings.appearance") {
                    FRSegmentedPills(FRAppearance.allCases, selection: Binding(
                        get: { FRAppearance(rawValue: appearance) ?? .system },
                        set: { appearance = $0.rawValue }
                    )) { $0.labelKey }
                }
                section("settings.notifications") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: $shiftNotifications) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("settings.notifications.roster").frText(FRType.rowTitle)
                                Text("settings.notifications.roster.body")
                                    .frText(FRType.rowSubtitle)
                                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                            }
                        }
                        .tint(Color.foodrun.toggleOn)
                        .padding(14)
                        .background(card)
                        .frNeu(.raised)
                        if systemAllowed == false {
                            // iOS blocks Foodrun: the switch above can't help until that is allowed.
                            Button {
                                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                            } label: {
                                Label("settings.notifications.blocked", systemImage: "exclamationmark.circle")
                                    .frText(FRType.rowSubtitle)
                                    .foregroundStyle(Color.foodrun.subject.warning)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                section("profile.language") {
                    FRSegmentedPills(FRLanguage.allCases, selection: Binding(
                        get: { FRLanguage(rawValue: language) ?? .system },
                        set: { FRLanguage.set($0); language = $0.rawValue }
                    )) { LocalizedStringKey(stringLiteral: $0.displayName) }
                }
                section("settings.about") {
                    HStack {
                        Text("settings.version").frText(FRType.rowTitle)
                        Spacer()
                        Text(verbatim: FoodrunVersion.text)
                            .frText(FRType.rowSubtitle)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    .padding(14)
                    .background(card)
                    .frNeu(.raised)
                }
                // Last, small and red: deleting needs the word typed on its own page.
                Button { confirmDelete = true } label: {
                    Text("profile.deleteAccount")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.foodrun.subject.destructive)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(.horizontal, FRSpacing.screenH.value)
            .padding(.top, FRSpacing.screenTop.value)
            .padding(.bottom, FRSpacing.screenBottom.value)
        }
        .background(Color.foodrun.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await checkSystem() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await checkSystem() } } }
        .sheet(isPresented: $confirmDelete) {
            DeleteAccountSheet {
                if await auth.deleteAccount() { FRHaptic.success.fire(); return true }
                FRHaptic.error.fire()
                deleteFailed = true
                return false
            }
        }
        .alert("profile.deleteAccount.failed", isPresented: $deleteFailed) {
            Button("action.ok", role: .cancel) {}
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.foodrun.foreground)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.foodrun.card))
                    .frNeu(.raised)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("action.back"))
            Text("settings.title").font(.system(size: 28, weight: .bold)).tracking(-0.8)
        }
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card)
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).frText(FRType.sectionHeader)
            content()
        }
    }

    private func checkSystem() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAllowed = settings.authorizationStatus != .denied
    }
}
