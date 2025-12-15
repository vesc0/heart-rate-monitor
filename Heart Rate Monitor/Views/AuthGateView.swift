import SwiftUI

struct AuthGateView: View {
    @State private var mode: Mode = .login
    
    var body: some View {
        VStack(spacing: 16) {
            // Mode switcher
            Picker("Mode", selection: $mode) {
                Text("Login").tag(Mode.login)
                Text("Sign Up").tag(Mode.signup)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 4)
            
            if mode == .login {
                LoginView()
            } else {
                SignUpView()
            }
        }
        .padding(.vertical)
    }
    
    enum Mode { case login, signup }
}

