import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state

    @Published var isSignedIn: Bool
    @Published var currentEmail: String?
    @Published var username: String?
    @Published var age: String?
    @Published var healthIssues: String?

    // MARK: - Private

    private let api = APIService.shared

    private let emailKey        = "auth.email"
    private let usernameKey     = "auth.username"
    private let ageKey          = "auth.age"
    private let healthIssuesKey = "auth.healthIssues"

    private var tokenObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        let hasToken = APIService.shared.isAuthenticated
        self.isSignedIn = hasToken

        if hasToken {
            self.currentEmail  = UserDefaults.standard.string(forKey: emailKey)
            self.username      = UserDefaults.standard.string(forKey: usernameKey)
            self.age           = UserDefaults.standard.string(forKey: ageKey)
            self.healthIssues  = UserDefaults.standard.string(forKey: healthIssuesKey)
        } else {
            self.currentEmail = nil
            self.username     = nil
            self.age          = nil
            self.healthIssues = nil
        }

        // Auto sign-out when the API layer detects a 401 (expired/invalid token)
        tokenObserver = NotificationCenter.default.addObserver(
            forName: .authTokenExpired, object: nil, queue: .main
        ) { [weak self] _ in
            self?.handleTokenExpired()
        }
    }

    deinit {
        if let observer = tokenObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Auth actions

    func signUp(email: String, password: String) async throws {
        guard validateEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 6   else { throw AuthError.weakPassword }

        do {
            try await api.register(email: email, password: password)
            // Auto-login after successful registration
            let response = try await api.login(email: email, password: password)
            applyLoginResponse(response, fallbackEmail: email)
        } catch let error as AuthError {
            throw error
        } catch let error as APIError {
            throw AuthError.generic(error.errorDescription ?? "Registration failed.")
        }
    }

    func signIn(email: String, password: String) async throws {
        guard validateEmail(email)  else { throw AuthError.invalidEmail }
        guard !password.isEmpty     else { throw AuthError.emptyPassword }

        do {
            let response = try await api.login(email: email, password: password)
            applyLoginResponse(response, fallbackEmail: email)
        } catch let error as AuthError {
            throw error
        } catch let error as APIError {
            throw AuthError.generic(error.errorDescription ?? "Login failed.")
        }
    }

    func signOut() {
        api.logout()
        isSignedIn   = false
        currentEmail = nil
        username     = nil
        age          = nil
        healthIssues = nil
        clearPersistedProfile()
    }

    // MARK: - Profile

    // Fetch the current user's profile from the server and update local state.
    func fetchProfile() async {
        guard api.isAuthenticated else { return }
        do {
            let profile = try await api.fetchProfile()
            username     = profile.username
            currentEmail = profile.email
            age          = profile.age.map { String($0) }
            healthIssues = profile.healthIssues
            persistProfile()
        } catch {
            // Keep cached data on error — server refresh is best-effort.
            print("[AuthVM] fetchProfile failed: \(error)")
        }
    }

    // Push a profile update to the server. Only non-nil fields are sent.
    func updateProfile(
        username: String? = nil,
        email: String? = nil,
        age: Int? = nil,
        healthIssues: String? = nil
    ) async throws {
        guard api.isAuthenticated else { return }
        do {
            let updated = try await api.updateProfile(
                username: username,
                email: email,
                age: age,
                healthIssues: healthIssues
            )
            self.username     = updated.username
            self.currentEmail = updated.email
            self.age          = updated.age.map { String($0) }
            self.healthIssues = updated.healthIssues
            persistProfile()
        } catch let error as APIError {
            throw AuthError.generic(error.errorDescription ?? "Update failed.")
        }
    }

    // MARK: - Helpers

    private func applyLoginResponse(_ response: AuthTokenResponse, fallbackEmail: String) {
        currentEmail = response.email ?? fallbackEmail
        username     = response.username
        age          = response.age.map { String($0) }
        healthIssues = response.healthIssues
        isSignedIn   = true
        persistProfile()
    }

    private func persistProfile() {
        let ud = UserDefaults.standard
        ud.set(currentEmail, forKey: emailKey)
        ud.set(username,     forKey: usernameKey)
        ud.set(age,          forKey: ageKey)
        ud.set(healthIssues, forKey: healthIssuesKey)
    }

    private func clearPersistedProfile() {
        let ud = UserDefaults.standard
        for key in [emailKey, usernameKey, ageKey, healthIssuesKey] {
            ud.removeObject(forKey: key)
        }
    }

    private func handleTokenExpired() {
        guard isSignedIn else { return }
        signOut()
    }

    private func validateEmail(_ email: String) -> Bool {
        email.contains("@") && email.contains(".") && email.count >= 5
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case invalidEmail
        case weakPassword
        case emptyPassword
        case generic(String)

        var errorDescription: String? {
            switch self {
            case .invalidEmail:     return "Please enter a valid email address."
            case .weakPassword:     return "Password should be at least 6 characters."
            case .emptyPassword:    return "Password cannot be empty."
            case .generic(let msg): return msg
            }
        }
    }
}

