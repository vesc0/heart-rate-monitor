import Foundation
import SwiftUI

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state

    @Published var isSignedIn: Bool
    @Published var currentEmail: String?
    @Published var username: String?
    @Published var age: String?
    @Published var gender: String?
    @Published var heightCm: String?
    @Published var weightKg: String?
    @Published var healthIssues: String?

    // MARK: - Private

    private let api = APIService.shared

    private let emailKey        = "auth.email"
    private let usernameKey     = "auth.username"
    private let ageKey          = "auth.age"
    private let genderKey       = "auth.gender"
    private let heightCmKey     = "auth.heightCm"
    private let weightKgKey     = "auth.weightKg"
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
            self.gender        = UserDefaults.standard.string(forKey: genderKey)
            self.heightCm      = UserDefaults.standard.string(forKey: heightCmKey)
            self.weightKg      = UserDefaults.standard.string(forKey: weightKgKey)
            self.healthIssues  = UserDefaults.standard.string(forKey: healthIssuesKey)
        } else {
            self.currentEmail = nil
            self.username     = nil
            self.age          = nil
            self.gender       = nil
            self.heightCm     = nil
            self.weightKg     = nil
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
        gender       = nil
        heightCm     = nil
        weightKg     = nil
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
            gender       = profile.gender
            heightCm     = profile.heightCm.map { String($0) }
            weightKg     = profile.weightKg.map { String($0) }
            healthIssues = profile.healthIssues
            persistProfile()
        } catch {
            print("[AuthVM] fetchProfile failed: \(error)")
        }
    }

    func updateProfile(
        username: String? = nil,
        email: String? = nil,
        age: Int? = nil,
        gender: String? = nil,
        heightCm: Int? = nil,
        weightKg: Int? = nil,
        healthIssues: String? = nil
    ) async throws {
        guard api.isAuthenticated else { return }
        do {
            let updated = try await api.updateProfile(
                username: username,
                email: email,
                age: age,
                gender: gender,
                heightCm: heightCm,
                weightKg: weightKg,
                healthIssues: healthIssues
            )
            self.username     = updated.username
            self.currentEmail = updated.email
            self.age          = updated.age.map { String($0) }
            self.gender       = updated.gender
            self.heightCm     = updated.heightCm.map { String($0) }
            self.weightKg     = updated.weightKg.map { String($0) }
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
        gender       = response.gender
        heightCm     = response.heightCm.map { String($0) }
        weightKg     = response.weightKg.map { String($0) }
        healthIssues = response.healthIssues
        isSignedIn   = true
        persistProfile()
    }

    private func persistProfile() {
        let ud = UserDefaults.standard
        ud.set(currentEmail, forKey: emailKey)
        ud.set(username,     forKey: usernameKey)
        ud.set(age,          forKey: ageKey)
        ud.set(gender,       forKey: genderKey)
        ud.set(heightCm,     forKey: heightCmKey)
        ud.set(weightKg,     forKey: weightKgKey)
        ud.set(healthIssues, forKey: healthIssuesKey)
    }

    private func clearPersistedProfile() {
        let ud = UserDefaults.standard
        for key in [emailKey, usernameKey, ageKey, genderKey, heightCmKey, weightKgKey, healthIssuesKey] {
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

