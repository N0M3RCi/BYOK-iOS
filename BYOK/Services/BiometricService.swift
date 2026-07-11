import Foundation
import LocalAuthentication

/// Handles Face ID / Touch ID authentication.
final class BiometricService: @unchecked Sendable {
    static let shared = BiometricService()

    private init() {}

    enum BiometricType {
        case faceID
        case touchID
        case none

        var displayName: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .none: return "None"
            }
        }
    }

    /// Returns the available biometric type on the device.
    func availableBiometricType() -> BiometricType {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        return context.biometryType == .faceID ? .faceID : .touchID
    }

    /// Checks if biometrics are available.
    func isAvailable() -> Bool {
        availableBiometricType() != .none
    }

    /// Authenticates the user with Face ID / Touch ID.
    func authenticate(reason: String = "Unlock M3RCI") async throws -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if let error = error {
                throw error
            }
            return false
        }
        return try await context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason
        )
    }
}