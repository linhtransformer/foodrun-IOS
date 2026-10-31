import SwiftUI
import UserNotifications

// Ik → Instellingen: one list like the iPhone's own settings — icon, label, and a switch or
// value on the right. Stored on the phone, except deleting the account (delete-my-account).

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var auth: AuthViewModel

    @AppStorage(FRAppearance.storageKey) private var appearance = FRAppearance.light.rawValue
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
                group {
                    toggleRow("moon.fill", "settings.darkMode", isOn: Binding(
                        get: { appearance == FRAppearance.dark.rawValue },
                        set: { appearance = ($0 ? FRAppearance.dark : .light).rawValue; FRHaptic.light.fire() }
                    ))
                    divider
                    toggleRow("bell.fill", "settings.notifications.roster", isOn: $shiftNotifications)
                    divider
                    languageRow
                }
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
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, -12)
                }
                group {
                    HStack(spacing: 12) {
                        icon("info.circle.fill")
                        Text("settings.version").frText(FRType.rowTitle)
                        Spacer()
                        Text(verbatim: FoodrunVersion.text)
                            .frText(FRType.rowSubtitle)
                            .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                    }
                    .padding(.horizontal, 14).frame(minHeight: 52)
                }
                // Last, on its own and red: deleting needs the word typed on its own page.
                group {
                    Button { confirmDelete = true } label: {
                        HStack(spacing: 12) {
                            icon("trash.fill", tint: Color.foodrun.subject.destructive)
                            Text("profile.deleteAccount")
                                .frText(FRType.rowTitle)
                                .foregroundStyle(Color.foodrun.subject.destructive)
                            Spacer()
                        }
                        .padding(.horizontal, 14).frame(minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
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

    // MARK: - Rows

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

    /// One white card holding rows, like an iOS settings group.
    private func group<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .background(RoundedRectangle(cornerRadius: FRRadius.listRowLg.value, style: .continuous).fill(Color.foodrun.card))
            .frNeu(.raised)
    }

    private var divider: some View {
        Rectangle().fill(Color.foodrun.border).frame(height: 1).padding(.leading, 58)
    }

    private func icon(_ symbol: String, tint: Color = Color.foodrun.foreground) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 32, height: 32)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.foodrun.neuTrack))
    }

    private func toggleRow(_ symbol: String, _ label: LocalizedStringKey, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                icon(symbol)
                Text(label).frText(FRType.rowTitle)
            }
        }
        .tint(Color.foodrun.toggleOn)
        .padding(.horizontal, 14).frame(minHeight: 52)
    }

    private var languageRow: some View {
        Menu {
            ForEach(FRLanguage.allCases) { option in
                Button {
                    FRLanguage.set(option)
                    language = option.rawValue
                } label: {
                    if option.rawValue == language {
                        Label(option.displayName, systemImage: "checkmark")
                    } else {
                        Text(verbatim: option.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                icon("globe")
                Text("profile.language").frText(FRType.rowTitle).foregroundStyle(Color.foodrun.foreground)
                Spacer()
                Text(verbatim: (FRLanguage(rawValue: language) ?? .system).displayName)
                    .frText(FRType.rowSubtitle)
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.foodrun.mutedForegroundSoft)
            }
            .padding(.horizontal, 14).frame(minHeight: 52)
            .contentShape(Rectangle())
        }
    }

    private func checkSystem() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAllowed = settings.authorizationStatus != .denied
    }
}
