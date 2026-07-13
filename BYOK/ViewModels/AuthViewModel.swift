import Foundation
import SwiftUI

/// Manages authentication state and login/signup flows.
@MainActor
final class AuthViewModel: ObservableObject {
    enum AuthState: Equatable {
        case unknown
        case needsPasscode
        case needsLogin
        case needsSignUp
        case authenticated
    }

    @Published var authState: AuthState = .unknown
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: User?
    @Published var token: String?

    private let apiClient = APIClient.shared
    private let keychain = KeychainManager.shared

    // MARK: - Auto Login

    func checkAutoLogin() {
        Task {
            guard let token = keychain.getToken() else {
                authState = .needsPasscode
                return
            }
            self.token = token
            // Token exists — go straight to authenticated
            authState = .authenticated
        }
    }

    // MARK: - Passcode Login (matches web app's passcode-login endpoint)

    func passcodeLogin(code: String) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.rawRequest(
                method: "POST",
                path: "/auth/passcode-login",
                body: ["passcode": code]
            )
            if let token = response["token"] as? String {
                self.token = token
                keychain.saveToken(token)
                if let email = response["email"] as? String {
                    keychain.saveEmail(email)
                }
                authState = .authenticated
                return nil
            }
            let text = response["text"] as? String ?? "Invalid passcode"
            return text
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Passcode Register (matches web app's passcode-register endpoint)

    func passcodeRegister(name: String) async -> (passcode: String?, error: String?) {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.rawRequest(
                method: "POST",
                path: "/auth/passcode-register",
                body: ["name": name]
            )
            if let passcode = response["passcode"] as? String {
                return (passcode, nil)
            }
            let text = response["text"] as? String ?? "Registration failed"
            return (nil, text)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    // MARK: - Email/Password Login (used by LoginView)

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let error = await adminLogin(email: email, password: password)
        if let error {
            errorMessage = error
        }
    }

    // MARK: - Admin Login (matches web app's user/login endpoint)

    func adminLogin(email: String, password: String) async -> String? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await apiClient.rawRequest(
                method: "POST",
                path: "/user/login",
                body: ["email": email, "password": password]
            )
            if let token = response["access_token"] as? String {
                self.token = token
                keychain.saveToken(token)
                keychain.saveEmail(email)
                authState = .authenticated
                return nil
            }
            if let detail = response["detail"] as? String {
                return detail
            }
            let text = response["text"] as? String ?? "Login failed"
            return text
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Sign Up (email/password)

    func signUp(email: String, password: String, confirmPassword: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            return
        }

        do {
            let response = try await apiClient.rawRequest(
                method: "POST",
                path: "/auth/register",
                body: ["email": email, "password": password]
            )
            if let token = response["access_token"] as? String {
                self.token = token
                keychain.saveToken(token)
                keychain.saveEmail(email)
                authState = .authenticated
            } else if let detail = response["detail"] as? String {
                errorMessage = detail
            } else {
                errorMessage = "Sign up failed"
            }
        } catch {
            errorMessage = error.localizedDescription
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
            authState = .needsPasscode
        }
    }
}
