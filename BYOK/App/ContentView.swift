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

            ChatListView()
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

// Placeholder views for references that don't exist yet
struct ChatListView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "message")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("Chat")
                    .font(.title2.bold())
                Text("Chat interface coming soon")
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button(role: .destructive, action: { authViewModel.logout() }) {
                        Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}