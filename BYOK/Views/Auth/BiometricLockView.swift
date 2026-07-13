import SwiftUI

struct BiometricLockView: View {
    @State private var isUnlocked = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black)
                    .frame(width: 80, height: 80)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.themeYellow, lineWidth: 2))
                    .shadow(color: Color.themeYellow.opacity(0.2), radius: 12)
                Text("🔒")
                    .font(.system(size: 30))
            }

            Text("M3RCI-UniMind")
                .font(.title.bold())
                .foregroundColor(.primary)

            Text("Authenticate to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if showError {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            Button(action: authenticate) {
                HStack {
                    Image(systemName: "faceid")
                        .font(.title2)
                    Text("Unlock")
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.accentTeal)
                .cornerRadius(12)
            }

            Spacer()
        }
        .background(Color(.systemBackground))
        .onAppear {
            authenticate()
        }
    }

    private func authenticate() {
        guard BiometricService.shared.isAvailable() else {
            isUnlocked = true
            return
        }
        Task {
            do {
                let success = try await BiometricService.shared.authenticate()
                if success {
                    isUnlocked = true
                } else {
                    showError = true
                    errorMessage = "Authentication failed"
                }
            } catch {
                showError = true
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Lock Screen Modifier
struct LockScreenModifier: ViewModifier {
    @State private var isLocked = false
    @AppStorage("biometric_enabled") private var biometricEnabled = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isLocked && biometricEnabled {
                    BiometricLockView()
                        .transition(.opacity)
                        .animation(.easeInOut, value: isLocked)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                if biometricEnabled {
                    isLocked = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if biometricEnabled && isLocked {
                    // Lock screen is already showing, authentication will unlock
                }
            }
    }
}

extension View {
    func biometricLock() -> some View {
        modifier(LockScreenModifier())
    }
}