import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                SplashView()
            case .needsLogin:
                LoginView()
            case .needsSignUp:
                SignUpView()
            case .needsPasscode:
                PasscodeView(mode: .enter)
            case .needsPasscodeSetup:
                PasscodeView(mode: .create)
            case .authenticated:
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authViewModel.authState)
    }
}

struct SplashView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            Text("M3RCI")
                .font(.largeTitle.bold())
            Text("UniMind")
                .font(.title2)
                .foregroundColor(.secondary)
            ProgressView()
                .padding(.top, 24)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }

            AgentsListView()
                .tabItem {
                    Label("Agents", systemImage: "person.2")
                }

            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
        .environmentObject(ThemeManager())
}