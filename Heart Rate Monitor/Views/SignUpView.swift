import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var errorText: String?
    var inPopup: Bool = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirm
    }
    
    private var canSubmit: Bool {
        passwordsMatch && email.contains("@") && !isLoading
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.bottom, 2)
            
            Text("Sign up to sync and back up your measurements.")
                .foregroundColor(.secondary)
                .padding(.bottom, 14)
            
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                HStack {
                    if showPassword {
                        TextField("Password (min 6 characters)", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        SecureField("Password (min 6 characters)", text: $password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
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
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                SecureField("Confirm Password", text: $confirm)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                
                if !passwordsMatch && !confirm.isEmpty {
                    Text("Passwords do not match.")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .transition(.opacity)
                }
                
                if let err = errorText {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.footnote)
                }
                
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView().progressViewStyle(.circular)
                        } else {
                            Image(systemName: "person.badge.plus.fill")
                        }
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundColor(.white)
                }
                .disabled(!canSubmit)
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
            try await auth.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                  password: password)
            submitHaptic(success: true)
        } catch {
            submitHaptic(success: false)
            errorText = (error as? LocalizedError)?.errorDescription ?? "Sign up failed. Please try again."
        }
        isLoading = false
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, @ViewBuilder then: (Self) -> Content) -> some View {
        if condition {
            then(self)
        } else {
            self
        }
    }
}
