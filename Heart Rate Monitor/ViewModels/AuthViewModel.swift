import Foundation
import SwiftUI
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isSignedIn: Bool
    @Published var currentEmail: String?
    
    // For demo: persist only a boolean and email to UserDefaults
    private let signedInKey = "auth.signedIn"
    private let emailKey = "auth.email"
    
    init() {
        let signed = UserDefaults.standard.bool(forKey: signedInKey)
        let email = UserDefaults.standard.string(forKey: emailKey)
        self.isSignedIn = signed
        self.currentEmail = email
    }
    
    func signUp(email: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000) // Simulate latency
        // Simple demo validations (to be replaced with backend logic)
        guard validateEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 6 else { throw AuthError.weakPassword }
        // In production will be calling API, handling errors, storing tokens securely....
        completeSignIn(email: email)
    }
    
    func signIn(email: String, password: String) async throws {
        try await Task.sleep(nanoseconds: 250_000_000) // Simulate latency
        guard validateEmail(email) else { throw AuthError.invalidEmail }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        // For demo we accept any non-empty password, to be replaced with real verification.
        completeSignIn(email: email)
    }
    
    func signOut() {
        isSignedIn = false
        currentEmail = nil
        UserDefaults.standard.set(false, forKey: signedInKey)
        UserDefaults.standard.removeObject(forKey: emailKey)
    }
    
    private func completeSignIn(email: String) {
        isSignedIn = true
        currentEmail = email
        UserDefaults.standard.set(true, forKey: signedInKey)
        UserDefaults.standard.set(email, forKey: emailKey)
    }
    
    private func validateEmail(_ email: String) -> Bool {
        // Very light validation
        email.contains("@") && email.contains(".") && email.count >= 5
    }
    
    enum AuthError: LocalizedError {
        case invalidEmail
        case weakPassword
        case emptyPassword
        case generic(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidEmail: return "Please enter a valid email address."
            case .weakPassword: return "Password should be at least 6 characters."
            case .emptyPassword: return "Password cannot be empty."
            case .generic(let msg): return msg
            }
        }
    }
}

