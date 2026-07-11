import SwiftUI
import LocalAuthentication

enum PasscodeMode {
    case enter
    case create
    case change
    case remove
}

struct PasscodeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let mode: PasscodeMode

    @State private var passcode = ""
    @State private var confirmPasscode = ""
    @State private var currentPasscode = ""
    @State private var step = 1
    @State private var errorMessage: String?
    @State private var useBiometrics = false

    private let passcodeLength = 6

    var title: String {
        switch mode {
        case .enter: return "Enter Passcode"
        case .create: return "Create Passcode"
        case .change: return "Change Passcode"
        case .remove: return "Remove Passcode"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 56))
                .foregroundColor(.accentTeal)

            Text(title)
                .font(.title2.bold())

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            // Passcode dots
            HStack(spacing: 12) {
                ForEach(0..<passcodeLength, id: \.self) { index in
                    Circle()
                        .fill(index < passcode.count ? Color.accentTeal : Color(.systemGray4))
                        .frame(width: 16, height: 16)
                }
            }

            // Biometric option
            if mode == .enter && BiometricService.shared.isAvailable() {
                Button(action: authenticateWithBiometrics) {
                    HStack {
                        Image(systemName: BiometricService.shared.availableBiometricType() == .faceID ? "faceid" : "touchid")
                        Text(BiometricService.shared.availableBiometricType() == .faceID ? "Use Face ID" : "Use Touch ID")
                    }
                    .foregroundColor(.accentTeal)
                }
            }

            Spacer()

            // Numeric keypad
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                ForEach(1...9, id: \.self) { number in
                    keypadButton("\(number)")
                }
                keypadButton("")
                keypadButton("0")
                keypadButton("delete.left") {
                    if !passcode.isEmpty { passcode.removeLast() }
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .onChange(of: passcode) { newValue in
            if newValue.count == passcodeLength {
                handlePasscodeEntry()
            }
        }
    }

    private func keypadButton(_ label: String, action: (() -> Void)? = nil) -> some View {
        Button(action: {
            if let action = action { action() }
            else if passcode.count < passcodeLength { passcode += label }
        }) {
            if label == "delete.left" {
                Image(systemName: label)
                    .font(.title2)
                    .foregroundColor(.primary)
            } else {
                Text(label)
                    .font(.title)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .disabled(label.isEmpty)
        .opacity(label.isEmpty ? 0 : 1)
    }

    private func handlePasscodeEntry() {
        switch mode {
        case .enter:
            if authViewModel.verifyPasscode(passcode) {
                if UserDefaults.standard.bool(forKey: "biometric_enabled") && BiometricService.shared.isAvailable() {
                    Task {
                        if try await BiometricService.shared.authenticate() {
                            authViewModel.authState = .authenticated
                        } else {
                            passcode = ""
                        }
                    }
                } else {
                    authViewModel.authState = .authenticated
                }
            } else {
                errorMessage = "Incorrect passcode"
                passcode = ""
            }

        case .create:
            if step == 1 {
                currentPasscode = passcode
                passcode = ""
                step = 2
            } else {
                if passcode == currentPasscode {
                    authViewModel.setPasscode(passcode)
                } else {
                    errorMessage = "Passcodes do not match"
                    passcode = ""
                    step = 1
                }
            }

        case .change:
            if step == 1 {
                if authViewModel.verifyPasscode(passcode) {
                    passcode = ""
                    step = 2
                } else {
                    errorMessage = "Incorrect passcode"
                    passcode = ""
                }
            } else if step == 2 {
                currentPasscode = passcode
                passcode = ""
                step = 3
            } else {
                if passcode == currentPasscode {
                    authViewModel.setPasscode(passcode)
                    authViewModel.authState = .authenticated
                } else {
                    errorMessage = "Passcodes do not match"
                    passcode = ""
                    step = 2
                }
            }

        case .remove:
            if authViewModel.verifyPasscode(passcode) {
                Task {
                    if await authViewModel.removePasscode() {
                        authViewModel.authState = .needsPasscodeSetup
                    }
                }
            } else {
                errorMessage = "Incorrect passcode"
                passcode = ""
            }
        }
    }

    private func authenticateWithBiometrics() {
        Task {
            if try await BiometricService.shared.authenticate() {
                authViewModel.authState = .authenticated
            }
        }
    }
}

#Preview {
    PasscodeView(mode: .enter)
        .environmentObject(AuthViewModel())
}