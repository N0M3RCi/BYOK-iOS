import Foundation
import SwiftUI

/// Manages authentication state and login/signup flows.
@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case needsLogin
        case needsSignUp
        case needsPasscode
        case needsPasscodeSetup
        case authenticated
    }

    @Published var authState: AuthState = .unknown
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: User?
    @Published var token: String?
    @Published var biometricEnabled = false

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared

    init() {
        biometricEnabled = UserDefaults.standard.bool(forKey: "biometric_enabled")
    }

    // MARK: - Auto Login

    func checkAutoLogin() {
        Task {
            guard let token = keychain.getToken() else {
                authState = hasPasscode() ? .needsPasscode : .needsLogin
                return
            }
            self.token = token
            if hasPasscode() {
                authState = .needsPasscode
                return
            }
            await performAutoLogin(token: token)
        }
    }

    private func hasPasscode() -> Bool {
        keychain.hasPasscode()
    }

    private func performAutoLogin(token: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let response: LoginResponse = try await apiClient.apiRequest(
                method: "POST",
                path: "/user/auto-login",
                requiresAuth: true
            )
            if response.code == 0 {
                self.token = token
                if let userId = response.userId {
                    keychain.saveUserID("\(userId)")
                }
                authState = .authenticated
            } else {
                keychain.clearAll()
                authState = .needsLogin
            }
        } catch {
            keychain.clearAll()
            authState = .needsLogin
        }
        isLoading = false
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let body = LoginRequest(email: email, password: password)
            let response: LoginResponse = try await apiClient.apiRequest(
                method: "POST",
                path: "/user/login",
                body: body,
                requiresAuth: false
            )
            if response.code == 0, let token = response.token {
                self.token = token
                keychain.saveToken(token)
                keychain.saveEmail(email)
                if let userId = response.userId {
                    keychain.saveUserID("\(userId)")
                }
                if !keychain.hasPasscode() {
                    authState = .needsPasscodeSetup
                } else {
                    authState = .authenticated
                }
            } else {
                errorMessage = response.text ?? "Login failed"
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Sign Up

    func signUp(email: String, password: String, confirmPassword: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let body = SignUpRequest(email: email, password: password, confirmPassword: confirmPassword)
            let response: LoginResponse = try await apiClient.apiRequest(
                method: "POST",
                path: "/user/sign-up",
                body: body,
                requiresAuth: false
            )
            if response.code == 0 {
                authState = .needsLogin
            } else {
                errorMessage = response.text ?? "Sign up failed"
            }
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Passcode

    func setPasscode(_ code: String) {
        Task {
            do {
                let body = PasscodeRequest(passcode: code)
                let _: LoginResponse = try await apiClient.apiRequest(
                    method: "POST",
                    path: "/user/passcode",
                    body: body
                )
                keychain.savePasscode(code)
                authState = .authenticated
            } catch {
                keychain.savePasscode(code)
                authState = .authenticated
            }
        }
    }

    func verifyPasscode(_ code: String) -> Bool {
        guard let stored = keychain.getPasscode() else { return false }
        return stored == code
    }

    func changePasscode(oldCode: String, newCode: String) async -> Bool {
        do {
            let body = PasscodeRequest(passcode: newCode)
            let _: LoginResponse = try await apiClient.apiRequest(
                method: "PUT",
                path: "/user/passcode",
                body: body
            )
            keychain.savePasscode(newCode)
            return true
        } catch {
            return false
        }
    }

    func removePasscode() async -> Bool {
        do {
            let _: EmptyResponse = try await apiClient.apiRequest(
                method: "DELETE",
                path: "/user/passcode"
            )
            keychain.deletePasscode()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Biometrics

    func authenticateWithBiometrics() async -> Bool {
        do {
            let success = try await BiometricService.shared.authenticate()
            return success
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Logout

    func logout() {
        Task {
            do {
                let _: EmptyResponse = try await apiClient.apiRequest(
                    method: "POST",
                    path: "/user/logout"
                )
            } catch {}
            keychain.clearAll()
            token = nil
            user = nil
            authState = .needsLogin
        }
    }

    // MARK: - Password Change

    func changePassword(oldPassword: String, newPassword: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let body = PasswordChangeRequest(oldPassword: oldPassword, newPassword: newPassword)
            let _: LoginResponse = try await apiClient.apiRequest(
                method: "PUT",
                path: "/user/password",
                body: body
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}