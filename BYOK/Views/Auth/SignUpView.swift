import SwiftUI

@MainActor
struct SignUpView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false

    var isValid: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && password == confirmPassword && password.count >= 6
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(.accentTeal)

                Text("Create Account")
                    .font(.largeTitle.bold())

                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.newPassword)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.newPassword)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                    if !confirmPassword.isEmpty && password != confirmPassword {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    Button(action: {
                        let authVM = _authViewModel.wrappedValue; Task { await authVM.signUp(email: email, password: password, confirmPassword: confirmPassword) }
                    }) {
                        HStack {
                            if authViewModel.isLoading { ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)) }
                            Text("Sign Up").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValid ? Color.accentTeal : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!isValid || authViewModel.isLoading)
                }
                .padding(.horizontal, 24)

                Spacer()

                HStack {
                    Text("Already have an account?")
                        .foregroundColor(.secondary)
                    Button("Login") {
                        authViewModel.authState = .needsLogin
                    }
                    .foregroundColor(.accentTeal)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}