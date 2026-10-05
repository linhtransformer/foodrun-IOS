import SwiftUI
import UserNotifications

@main
struct FoodrunApp: App {
    @StateObject private var auth = AuthViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.light) // v1: light-mode only. Dark mode: v2.
                .task {
                    await auth.bootstrap()
                }
                .onOpenURL { url in
                    // Magic link callback: foodrun://auth-callback?...
                    Task {
                        await auth.handleDeepLink(url)
                    }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { ShiftBackgroundRefresh.schedule() }
        }
        .backgroundTask(.appRefresh(ShiftBackgroundRefresh.taskId)) {
            await ShiftBackgroundRefresh.run()
        }
    }
}

/// Lets shift-change notifications show as a banner while the app is open too.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @AppStorage(FRLanguage.storageKey) private var language = FRLanguage.system.rawValue
    /// Lives above the shell so the open tab survives the rebuild on a language switch.
    @State private var router = TabRouter()

    var body: some View {
        ZStack {
            Color.foodrun.background.ignoresSafeArea()

            switch auth.state {
            case .loading:
                ProgressView()
                    .tint(Color.foodrun.foreground)
            case .signedOut:
                AuthViewRedesign()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .signedIn:
                // Rebuilt when the language changes so code-formatted dates and
                // labels re-render too, not just Text keys.
                AppShell(router: router)
                    .id(language)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(FRAnimation.enter, value: auth.state)
        .environment(\.locale, FRLanguage.locale)
    }
}
