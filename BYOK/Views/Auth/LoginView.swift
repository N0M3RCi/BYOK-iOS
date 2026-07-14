import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?

    enum Field {
        case email
        case password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 60)

                // Logo
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 72))
                    .foregroundColor(.accentTeal)

                Text("M3RCI")
                    .font(.largeTitle.bold())
                Text("UniMind")
                    .font(.title3)
                    .foregroundColor(.secondary)

                Spacer().frame(height: 20)

                // Login form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .focused($focusedField, equals: .email)

                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                        } else {
                            SecureField("Password", text: $password)
                                .textContentType(.password)
                                .focused($focusedField, equals: .password)
                        }
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }

                    // Login button
                    Button(action: {
                        Task { await authViewModel.login(email: email, password: password) }
                    }) {
                        HStack {
                            if authViewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text("Login")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(email.isEmpty || password.isEmpty ? Color.gray : Color.accentTeal)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(email.isEmpty || password.isEmpty || authViewModel.isLoading)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Sign up link
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    Button("Sign Up") {
                        authViewModel.authState = .needsSignUp
                    }
                    .foregroundColor(.accentTeal)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                focusedField = .email
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}