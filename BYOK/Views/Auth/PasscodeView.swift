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
    @State private var passcodeInput = ""
    @State private var registerName = ""
    @State private var adminEmail = ""
    @State private var adminPassword = ""
    @State private var registeredPasscode: String?
    @State private var localError: String?
    @FocusState private var focusedField: Field?

    enum Field {
        case passcode, adminEmail, adminPassword, register
    }

    var body: some View {
        ZStack {
            // Dark background
            Color(red: 0.08, green: 0.09, blue: 0.12)
                .ignoresSafeArea()

            // Subtle gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.5),
                    Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.8),
                    Color(red: 0.08, green: 0.09, blue: 0.12)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo / Branding (matching web app)
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(width: 64, height: 64)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.themeYellow, lineWidth: 2)
                            )
                            .shadow(color: Color.themeYellow.opacity(0.2), radius: 12, x: 0, y: 4)

                        Text("🤖")
                            .font(.system(size: 28))
                    }

                    Text("M3RCI - UniMind")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.bottom, 48)

                // Tab selector
                HStack(spacing: 0) {
                    ForEach(PasscodeTab.allCases, id: \.self) { tab in
                        Button(action: { selectedTab = tab; localError = nil; registeredPasscode = nil }) {
                            Text(tab.rawValue)
                                .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                .foregroundColor(selectedTab == tab ? .themeYellow : .white.opacity(0.5))
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .overlay(alignment: .bottom) {
                                    if selectedTab == tab {
                                        Rectangle().fill(Color.themeYellow).frame(height: 2)
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
                            .tint(.themeYellow)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 32)

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
                .foregroundColor(.white.opacity(0.9))

            TextField("Passcode", text: $passcodeInput)
                .focused($focusedField, equals: .passcode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, design: .monospaced))
                .foregroundColor(.themeYellow)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .padding(.horizontal, 20)
                .onChange(of: passcodeInput) { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { passcodeInput = filtered }
                    if filtered.count == 6 { submitPasscode(filtered) }
                }

            Button("Sign In") {
                guard passcodeInput.count == 6 else { return }
                submitPasscode(passcodeInput)
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.themeYellow)
            .cornerRadius(25)
            .padding(.horizontal, 20)
            .disabled(authViewModel.isLoading || passcodeInput.count != 6)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption)
                .foregroundColor(.white.opacity(0.4))
        }
        .onAppear { focusedField = .passcode }
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
                        .foregroundColor(.themeYellow)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).stroke(Color.themeYellow, lineWidth: 1))
                    Text("Save this passcode to sign in later")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    Button("Sign In") {
                        selectedTab = .student
                        registeredPasscode = nil
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.themeYellow)
                    .cornerRadius(25)
                    .padding(.horizontal, 20)
                }
            } else {
                Text("Register a New Account")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))

                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .register)
                    .autocapitalization(.words)

                Button("Register") {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }
                .font(.headline)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.themeYellow)
                .cornerRadius(25)
                .padding(.horizontal, 20)
                .disabled(authViewModel.isLoading || registerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { focusedField = .register }
    }

    // MARK: - Admin Login

    private var adminLoginView: some View {
        VStack(spacing: 20) {
            Text("Admin Login")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))

            VStack(spacing: 12) {
                TextField("Email", text: $adminEmail)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .focused($focusedField, equals: .adminEmail)

                SecureField("Password", text: $adminPassword)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white)
                    .focused($focusedField, equals: .adminPassword)
            }

            Button("Sign In") {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }
            .font(.headline)
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.themeYellow)
            .cornerRadius(25)
            .padding(.horizontal, 20)
            .disabled(authViewModel.isLoading)
        }
        .onAppear { focusedField = .adminEmail }
    }

    // MARK: - Actions

    private func submitPasscode(_ code: String) {
        Task {
            localError = nil
            if let error = await authViewModel.passcodeLogin(code: code) {
                localError = error
                passcodeInput = ""
                focusedField = .passcode
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

#Preview {
    PasscodeGateView()
        .environmentObject(AuthViewModel())
}