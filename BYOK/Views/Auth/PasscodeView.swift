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
            Color(red: 0.12, green: 0.14, blue: 0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Logo
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.black)
                            .frame(width: 56, height: 56)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#F5C842"), lineWidth: 2))
                        Text("🤖").font(.system(size: 24))
                    }

                    Text("M3RCI - UniMind")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)

                    // Tab selector
                    HStack(spacing: 0) {
                        ForEach(PasscodeTab.allCases, id: \.self) { tab in
                            Button(action: { selectedTab = tab; localError = nil; registeredPasscode = nil }) {
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                                    .foregroundColor(selectedTab == tab ? .black : .gray)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .overlay(alignment: .bottom) {
                                        if selectedTab == tab {
                                            Rectangle().fill(Color(hex: "#F5C842")).frame(height: 2)
                                        }
                                    }
                            }
                        }
                    }

                    // Form content
                    VStack(spacing: 20) {
                        switch selectedTab {
                        case .student: studentLoginView
                        case .register: registerView
                        case .admin: adminLoginView
                        }

                        if let err = localError ?? authViewModel.errorMessage {
                            Text(err).font(.caption).foregroundColor(.red).multilineTextAlignment(.center)
                        }
                        if authViewModel.isLoading {
                            ProgressView().tint(Color(hex: "#F5C842"))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: 360)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.15), radius: 24, x: 0, y: 8)
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Student Login

    private var studentLoginView: some View {
        VStack(spacing: 16) {
            Text("Enter Student Passcode")
                .font(.headline).foregroundColor(.black)

            TextField("Passcode", text: $passcodeInput)
                .focused($focusedField, equals: .passcode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, design: .monospaced))
                .foregroundColor(.black)
                .frame(height: 48)
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, 16)
                .onChange(of: passcodeInput) { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { passcodeInput = filtered }
                    if filtered.count == 6 { submitPasscode(filtered) }
                }

            Button("Sign In") {
                guard passcodeInput.count == 6 else { return }
                submitPasscode(passcodeInput)
            }
            .font(.headline).foregroundColor(.black)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(Color(hex: "#F5C842"))
            .cornerRadius(22)
            .disabled(authViewModel.isLoading || passcodeInput.count != 6)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption).foregroundColor(.gray)
        }
        .onAppear { focusedField = .passcode }
    }

    // MARK: - Register

    private var registerView: some View {
        VStack(spacing: 16) {
            if let passcode = registeredPasscode {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundColor(.green)
                    Text("Registration Successful!").font(.headline).foregroundColor(.black)
                    Text("Your passcode is:").foregroundColor(.gray)
                    Text(passcode).font(.system(size: 28, design: .monospaced)).fontWeight(.bold).foregroundColor(.black)
                        .padding().background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    Text("Save this passcode to sign in later").font(.caption).foregroundColor(.gray)
                    Button("Sign In") { selectedTab = .student; registeredPasscode = nil }
                        .font(.headline).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color(hex: "#F5C842")).cornerRadius(22)
                }
            } else {
                Text("Register a New Account").font(.headline).foregroundColor(.black)

                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain).padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.black)
                    .focused($focusedField, equals: .register)
                    .autocapitalization(.words)

                Button("Register") {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }
                .font(.headline).foregroundColor(.black)
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(Color(hex: "#F5C842")).cornerRadius(22)
                .disabled(authViewModel.isLoading || registerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { focusedField = .register }
    }

    // MARK: - Admin Login

    private var adminLoginView: some View {
        VStack(spacing: 16) {
            Text("Admin Login").font(.headline).foregroundColor(.black)

            VStack(spacing: 12) {
                TextField("Email", text: $adminEmail)
                    .textFieldStyle(.plain).padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.black).keyboardType(.emailAddress).autocapitalization(.none)
                    .focused($focusedField, equals: .adminEmail)

                SecureField("Password", text: $adminPassword)
                    .textFieldStyle(.plain).padding()
                    .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.black)
                    .focused($focusedField, equals: .adminPassword)
            }

            Button("Sign In") {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }
            .font(.headline).foregroundColor(.black)
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(Color(hex: "#F5C842")).cornerRadius(22)
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
            if let error { localError = error }
            else if let passcode { registeredPasscode = passcode }
        }
    }

    private func submitAdminLogin() {
        Task { localError = nil; await authViewModel.login(email: adminEmail, password: adminPassword) }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        self.init(
            .sRGB,
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview {
    PasscodeGateView()
        .environmentObject(AuthViewModel())
}