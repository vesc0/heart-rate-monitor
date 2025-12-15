import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    
    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn {
                    SignedInProfileCard()
                } else {
                    AuthGateView()
                }
            }
            .padding()
            .navigationTitle("Profile")
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct SignedInProfileCard: View {
    @EnvironmentObject private var auth: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.pink.opacity(0.8), .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 96, height: 96)
                Image(systemName: "person.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: 8)
            
            // Info
            VStack(spacing: 4) {
                Text(auth.currentEmail ?? "Unknown")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Premium not activated")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    // Placeholder for future settings
                } label: {
                    HStack {
                        Image(systemName: "gearshape.fill")
                        Text("Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                
                Button(role: .destructive) {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    auth.signOut()
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .padding()
                    .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
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

