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
        VStack(spacing: 0) {
            // Logo
            VStack(spacing: 16) {
                Spacer().frame(height: 60)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black)
                        .frame(width: 64, height: 64)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#EAB308"), lineWidth: 2))
                        .shadow(color: Color(hex: "#EAB308").opacity(0.15), radius: 12, x: 0, y: 4)

                    Text("🤖")
                        .font(.system(size: 28))
                }

                Text("M3RCI - UniMind")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.black)
            }
            .padding(.bottom, 32)

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
                                    Rectangle().fill(Color(hex: "#EAB308")).frame(height: 2)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 32)

            // Content
            ScrollView {
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
                        ProgressView().tint(Color(hex: "#EAB308"))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
            }
        }
        .background(Color.white.ignoresSafeArea())
    }

    // MARK: - Student Login

    private var studentLoginView: some View {
        VStack(spacing: 20) {
            TextField("Enter passcode", text: $passcodeInput)
                .focused($focusedField, equals: .passcode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 24, design: .monospaced))
                .foregroundColor(.black)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .onChange(of: passcodeInput) { newValue in
                    let filtered = String(newValue.filter(\.isNumber).prefix(6))
                    if filtered != newValue { passcodeInput = filtered }
                    if filtered.count == 6 { submitPasscode(filtered) }
                }

            Button(action: {
                guard passcodeInput.count == 6 else { return }
                submitPasscode(passcodeInput)
            }) {
                Text(authViewModel.isLoading ? "Signing in..." : "Sign In")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "#EAB308"))
                    .cornerRadius(24)
            }
            .disabled(authViewModel.isLoading || passcodeInput.count != 6)

            Text("Enter your 6-digit student passcode to sign in")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .onAppear { focusedField = .passcode }
    }

    // MARK: - Register

    private var registerView: some View {
        VStack(spacing: 20) {
            if let passcode = registeredPasscode {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundColor(.green)
                    Text("Registration Successful!").font(.headline).foregroundColor(.black)
                    Text("Your passcode is:").foregroundColor(.gray)
                    Text(passcode).font(.system(size: 32, design: .monospaced)).fontWeight(.bold).foregroundColor(.black)
                        .padding().background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    Text("Save this passcode to sign in later").font(.caption).foregroundColor(.gray)
                    Button("Sign In") { selectedTab = .student; registeredPasscode = nil }
                        .fontWeight(.semibold).foregroundColor(.black)
                        .frame(maxWidth: .infinity).frame(height: 48)
                        .background(Color(hex: "#EAB308")).cornerRadius(24)
                }
            } else {
                TextField("Your Name", text: $registerName)
                    .textFieldStyle(.plain).padding()
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .foregroundColor(.black)
                    .focused($focusedField, equals: .register)
                    .autocapitalization(.words)

                Button(action: {
                    guard !registerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    submitRegistration()
                }) {
                    Text("Register")
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(hex: "#EAB308"))
                        .cornerRadius(24)
                }
                .disabled(authViewModel.isLoading || registerName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear { focusedField = .register }
    }

    // MARK: - Admin Login

    private var adminLoginView: some View {
        VStack(spacing: 20) {
            TextField("Email", text: $adminEmail)
                .textFieldStyle(.plain).padding()
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .foregroundColor(.black).keyboardType(.emailAddress).autocapitalization(.none)
                .focused($focusedField, equals: .adminEmail)

            SecureField("Password", text: $adminPassword)
                .textFieldStyle(.plain).padding()
                .background(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .foregroundColor(.black)
                .focused($focusedField, equals: .adminPassword)

            Button(action: {
                guard !adminEmail.isEmpty, !adminPassword.isEmpty else { return }
                submitAdminLogin()
            }) {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(hex: "#EAB308"))
                    .cornerRadius(24)
            }
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