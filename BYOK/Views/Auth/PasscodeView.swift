import SwiftUI

// MARK: - Passcode Gate View

struct PasscodeGateView: View {
    @EnvironmentObject var authViewModel: AuthViewModel

    enum PasscodeTab: String, CaseIterable {
        case student = "Passcode"
        case register = "Register"
        case admin = "Admin"
    }

    @State private var selectedTab: PasscodeTab = .student
    @State private var passcode = ""
    @State private var registerName = ""
    @State private var adminEmail = ""
    @State private var adminPassword = ""
    @State private var registeredPasscode: String?
    @State private var localError: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 6) {
                Text("M3RCI")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))
                Text("UniMind")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.65))
                Text("AI Multi-Agent Workforce")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.7, green: 0.7, blue: 0.8))
                    .padding(.top, 2)
            }
            .padding(.bottom, 32)

            // Tab selector
            HStack(spacing: 0) {
                ForEach(PasscodeTab.allCases, id: \.self) { tab in
                    Button(action: { selectedTab = tab; localError = nil; registeredPasscode = nil }) {
                        Text(tab.rawValue)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(selectedTab == tab ? Color(red: 0.29, green: 0.0, blue: 0.51) : Color(red: 0.6, green: 0.6, blue: 0.7))
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) {
                                if selectedTab == tab {
                                    Rectangle()
                                        .fill(Color(red: 0.29, green: 0.0, blue: 0.51))
                                        .frame(height: 2.5)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 32)

            // Content
            VStack(spacing: 24) {
                switch selectedTab {
                case .student:
                    studentLoginView
                case .register:
                    registerView
                case .admin:
                    adminLoginView
                }

                if let err = localError ?? authViewModel.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                if authViewModel.isLoading {
                    ProgressView()
                        .tint(Color(red: 0.29, green: 0.0, blue: 0.51))
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Spacer()
        }
    }

    // MARK: - Student Login

    private var studentLoginView: some View {
        VStack(spacing: 20) {
            Text("Enter Student Passcode")
                .font(.headline)
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))

            UIKitTextField(
                text: $passcode,
                placeholder: "6-digit passcode",
                keyboardType: .numberPad,
                textAlignment: .center,
                font: .monospacedSystemFont(ofSize: 24, weight: .regular),
                textColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1),
                backgroundColor: UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1),
                cornerRadius: 10,
                borderColor: UIColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 1),
                borderWidth: 1,
                leftPadding: 16,
                shouldBecomeFirstResponder: false
            )
            .frame(height: 50)
            .onChange(of: passcode) { newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered.count > 6 { passcode = String(filtered.prefix(6)) }
                    else { passcode = filtered }
                    if passcode.count == 6 { submitPasscode(passcode) }
                }

            Button("Sign In") {
                guard passcode.count == 6 else { return }
                submitPasscode(passcode)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color(red: 0.29, green: 0.0, blue: 0.51))
            .cornerRadius(12)
            .disabled(authViewModel.isLoading || passcode.count != 6)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption)
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
        }
    }

    // MARK: - Register

    private var registerView: some View {
        VStack(spacing: 20) {
            if let passcode = registeredPasscode {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Registration Successful!")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))
                    Text("Your passcode is:")
                        .foregroundColor(Color(red: 0.55, green: 0.55, blue: 0.65))
                    Text(passcode)
                        .font(.system(size: 32, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(Color(red: 0.29, green: 0.0, blue: 0.51))
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(red: 0.29, green: 0.0, blue: 0.51), lineWidth: 1)
                        )
                    Text("Save this passcode to sign in later")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                    Button("Sign In") {
                        selectedTab = .student
                        registeredPasscode = nil
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.29, green: 0.0, blue: 0.51))
                    .cornerRadius(12)
                }
            } else {
                Text("Register a New Account")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))

                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.98))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color(red: 0.85, green: 0.85, blue: 0.92), lineWidth: 1)
                            )
                    )
                    .foregroundColor(Color(red: 0.2, green: 0.2, blue: 0.3))
                    .autocapitalization(.words)
                    .focused($focusedField, equals: "registerName")

                Button("Register") {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .background(Color(red: 0.29, green: 0.0, blue: 0.51))
                .cornerRadius(12)
                .disabled(authViewModel.isLoading || registerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Admin Login

    private var adminLoginView: some View {
        VStack(spacing: 20) {
            Text("Admin Login")
                .font(.headline)
                .foregroundColor(Color(red: 0.25, green: 0.25, blue: 0.35))

            VStack(spacing: 12) {
                UIKitTextField(
                    text: $adminEmail,
                    placeholder: "Email",
                    keyboardType: .emailAddress,
                    textColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1),
                    backgroundColor: UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1),
                    cornerRadius: 10,
                    borderColor: UIColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 1),
                    borderWidth: 1,
                    leftPadding: 16,
                    shouldBecomeFirstResponder: false
                )
                .frame(height: 50)

                UIKitTextField(
                    text: $adminPassword,
                    placeholder: "Password",
                    isSecure: true,
                    textColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1),
                    backgroundColor: UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1),
                    cornerRadius: 10,
                    borderColor: UIColor(red: 0.85, green: 0.85, blue: 0.92, alpha: 1),
                    borderWidth: 1,
                    leftPadding: 16,
                    shouldBecomeFirstResponder: false
                )
                .frame(height: 50)
            }

            Button("Sign In") {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color(red: 0.29, green: 0.0, blue: 0.51))
            .cornerRadius(12)
            .disabled(authViewModel.isLoading)
        }
    }

    // MARK: - Actions

    private func submitPasscode(_ code: String) {
        Task {
            localError = nil
            if let error = await authViewModel.passcodeLogin(code: code) {
                localError = error
                passcode = ""
            }
        }
    }

    private func submitRegistration() {
        Task {
            localError = nil
            let (passcode, error) = await authViewModel.passcodeRegister(name: registerName)
            if let error {
                localError = error
            } else if let passcode {
                registeredPasscode = passcode
            }
        }
    }

    private func submitAdminLogin() {
        Task {
            localError = nil
            await authViewModel.login(email: adminEmail, password: adminPassword)
        }
    }
}