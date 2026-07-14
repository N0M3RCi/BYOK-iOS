import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                SplashView()
            case .needsPasscode:
                PasscodeGateView()
            case .needsSignUp:
                PasscodeGateView()
            case .needsLogin:
                LoginView()
            case .authenticated:
                MainTabView()
            }
        }
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeYellow, lineWidth: 2))
                    .shadow(color: Color.themeYellow.opacity(0.2), radius: 12)
                Text("🤖")
                    .font(.system(size: 30))
            }

            Text("M3RCI-UniMind")
                .font(.title.bold())
                .foregroundColor(.primary)

            Text("AI Multi-Agent Workforce")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ProgressView()
                .padding(.top, 24)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    var body: some View {
        if horizontalSizeClass == .regular {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPhone Layout (TabView)
    private var iPhoneLayout: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house") }

            ChatView()
                .tabItem { Label("Chat", systemImage: "message") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }

    // MARK: - iPad Layout (NavigationSplitView)
    private var iPadLayout: some View {
        NavigationSplitView {
            List {
                NavigationLink(destination: DashboardView()) {
                    Label("Home", systemImage: "house")
                }
                NavigationLink(destination: ChatView()) {
                    Label("Chat", systemImage: "message")
                }
                NavigationLink(destination: SettingsView()) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .navigationTitle("M3RCI")
        } detail: {
            DashboardView()
        }
    }
}

// Note: ChatView and SettingsView are defined in their respective files