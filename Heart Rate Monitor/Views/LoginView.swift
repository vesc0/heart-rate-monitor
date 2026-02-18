import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorText: String?
    var inPopup: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome Back")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 2)
            
            Text("Log in to continue tracking your heart health.")
                .foregroundColor(.secondary)
                .padding(.bottom, 14)
            
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0), radius: 8, x: 0, y: 3)
                    .foregroundColor(.primary)
                
                HStack {
                    if showPassword {
                        TextField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(.primary)
                    } else {
                        SecureField("Password", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .foregroundColor(.primary)
                    }
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showPassword.toggle()
                        }
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(.separator), lineWidth: 1)
                )
                .shadow(color: .black.opacity(colorScheme == .light ? 0.06 : 0), radius: 8, x: 0, y: 3)
                
                if let err = errorText {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                        .transition(.opacity .combined(with: .move(edge: .top)))
                }
                
                Button {
                    Task {
                        await submit()
                    }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        Text("Log In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
                }
                .disabled(isLoading)
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .if(!inPopup) { view in
            view
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.04), radius: 12, x: 0, y: 6)
        }
    }
    
    private func submitHaptic(success: Bool) {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(success ? .success : .error)
    }
    
    private func submit() async {
        errorText = nil
        isLoading = true
        do {
            try await auth.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                  password: password)
            submitHaptic(success: true)
        } catch {
            submitHaptic(success: false)
            errorText = (error as? LocalizedError)?.errorDescription ?? "Login failed. Please try again."
        }
        isLoading = false
    }
}


