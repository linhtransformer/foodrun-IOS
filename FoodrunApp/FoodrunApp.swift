import SwiftUI

@main
struct FoodrunApp: App {
    @StateObject private var auth = AuthViewModel()

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
    }
}

struct RootView: View {
    @EnvironmentObject private var auth: AuthViewModel

    var body: some View {
        ZStack {
            Color.foodrun.background.ignoresSafeArea()

            switch auth.state {
            case .loading:
                ProgressView()
                    .tint(Color.foodrun.foreground)
            case .signedOut:
                AuthView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .signedIn:
                HomeView()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(FRAnimation.enter, value: auth.state)
    }
}
