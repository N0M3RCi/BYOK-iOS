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

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

// Note: ChatView and SettingsView are defined in their respective files