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
        ZStack {
            // Dark gradient background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.12),
                    Color(red: 0.08, green: 0.08, blue: 0.18)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Branding
                VStack(spacing: 8) {
                    Text("🤖")
                        .font(.system(size: 48))
                    Text("M3RCI-UniMind")
                        .font(.title.bold())
                        .foregroundColor(.white)
                    Text("AI Multi-Agent Workforce")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 40)

                // Tab selector
                HStack(spacing: 0) {
                    ForEach(PasscodeTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab; localError = nil; registeredPasscode = nil }) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .yellow : .white.opacity(0.5))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .bottom) {
                                    if selectedTab == tab {
                                        Rectangle().fill(Color.yellow).frame(height: 2)
                                    }
                                }
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        switch selectedTab {
                        case .student:
                            studentLoginView
                        case .register:
                            registerView
                        case .admin:
                            adminLoginView
                        }

                        // Error message
                        if let err = localError ?? authViewModel.errorMessage {
                            Text(err)
                                .font(.caption)
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                        }

                        // Loading indicator
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.yellow)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 32)
                }

                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Student Login

    private var studentLoginView: some View {
        VStack(spacing: 20) {
            Text("Enter Student Passcode")
                .font(.headline)
                .foregroundColor(.white)

            TextField("6-digit passcode", text: $passcode)
                .textFieldStyle(.plain)
                .padding()
                .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                .foregroundColor(.white)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, design: .monospaced))
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
            .foregroundColor(.black)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color.yellow)
            .cornerRadius(12)
            .disabled(authViewModel.isLoading || passcode.count != 6)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
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
                        .foregroundColor(.white)
                    Text("Your passcode is:")
                        .foregroundColor(.white.opacity(0.7))
                    Text(passcode)
                        .font(.system(size: 32, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.yellow, lineWidth: 1))
                    Text("Save this passcode to sign in later")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Button("Sign In") {
                        selectedTab = .student
                        registeredPasscode = nil
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 48)
                    .padding(.vertical, 14)
                    .background(Color.yellow)
                    .cornerRadius(12)
                }
            } else {
                Text("Register a New Account")
                    .font(.headline)
                    .foregroundColor(.white)

                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .autocapitalization(.words)

                Button("Register") {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding(.horizontal, 48)
                .padding(.vertical, 14)
                .background(Color.yellow)
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
                .foregroundColor(.white)

            VStack(spacing: 12) {
                TextField("Email", text: $adminEmail)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)

                SecureField("Password", text: $adminPassword)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.3)))
                    .foregroundColor(.white)
            }

            Button("Sign In") {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }
            .font(.headline)
            .foregroundColor(.black)
            .padding(.horizontal, 48)
            .padding(.vertical, 14)
            .background(Color.yellow)
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