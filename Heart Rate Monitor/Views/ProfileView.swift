import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showAuthPopup = false
    @State private var selectedAuthTab = 0 // 0 = Login, 1 = Sign Up
    @State private var editingField: EditableField? = nil
    @State private var profileError: String?
    
    enum EditableField: String, CaseIterable, Identifiable {
        case name, email, age, health
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Main content
                VStack(alignment: .leading, spacing: 20) {
                    if auth.isSignedIn {
                        // Signed In UI - Modern Card + Details
                        VStack(spacing: 16) {
                            profileHeaderCard
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Details")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                
                                VStack(spacing: 8) {
                                    profileRow(label: "Name", value: auth.username ?? "", editable: .name)
                                    profileRow(label: "Email", value: auth.currentEmail ?? "", editable: .email)
                                    profileRow(label: "Age", value: auth.age ?? "", editable: .age)
                                    profileRow(label: "Health Issues", value: auth.healthIssues ?? "", editable: .health)
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.secondarySystemGroupedBackground))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                                )
                            }
                            
                            Button(role: .destructive) {
                                let generator = UINotificationFeedbackGenerator()
                                generator.notificationOccurred(.warning)
                                auth.signOut()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                    Text("Sign Out")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(Color.red.opacity(0.18), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 4)
                            
                            if let err = profileError {
                                Text(err)
                                    .foregroundColor(.red)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity)
                    } else {
                        // Logged Out UI
                        VStack(spacing: 16) {
                            Text("Log in to access your profile, sync features,\nand view personal stats.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 2)
                            
                            Button {
                                showAuthPopup = true
                            } label: {
                                HStack {
                                    Image(systemName: "person.crop.circle.badge.plus")
                                    Text("Log In or Sign Up")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .foregroundColor(.white)
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                    
                    Spacer()
                }
                .padding(.top, 24)
                .blur(radius: showAuthPopup ? 8 : 0)
                .animation(.easeInOut(duration: 0.15), value: showAuthPopup)
                .disabled(showAuthPopup)
                
                // Modal popup for login/signup
                if showAuthPopup {
                    Color.black.opacity(0.32)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .zIndex(1)
                    
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Button {
                                showAuthPopup = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.secondary)
                                    .padding(5)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        
                        Picker("", selection: $selectedAuthTab) {
                            Text("Log In").tag(0)
                            Text("Sign Up").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        
                        // Scroll to avoid overflow if keyboard/content is taller than the popup
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                if selectedAuthTab == 0 {
                                    LoginView(inPopup: true)
                                        .environmentObject(auth)
                                        .padding(.horizontal)
                                } else {
                                    SignUpView(inPopup: true)
                                        .environmentObject(auth)
                                        .padding(.horizontal)
                                }
                            }
                            .padding(.bottom, 12)
                        }
                        .scrollIndicators(.hidden)
                    }
                    .frame(width: 370, height: selectedAuthTab == 0 ? 460 : 540)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .clipped()
                    .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(color: .black.opacity(0.13), radius: 32, x: 0, y: 12)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
                }
            }
            .sheet(item: $editingField) { field in
                EditFieldSheet(
                    field: field,
                    initialValue: currentValue(for: field),
                    onSave: { newValue in
                        saveProfileField(field, newValue: newValue)
                        editingField = nil
                    },
                    onCancel: { editingField = nil }
                )
            }
            .background(Color(.systemGroupedBackground))
            .animation(.easeInOut(duration: 0.18), value: showAuthPopup)
            .onChange(of: auth.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    showAuthPopup = false
                    profileError = nil
                }
            }
            .navigationTitle("Profile")
        }
    }
    
    // MARK: - Header Card with Avatar
    private var profileHeaderCard: some View {
        VStack(spacing: 14) {
            ZStack {
                // Subtle gradient ring behind avatar
                Circle()
                    .strokeBorder(
                        AngularGradient(gradient: Gradient(colors: [.pink, .red, .orange, .pink]),
                                        center: .center),
                        lineWidth: 3
                    )
                    .frame(width: 98, height: 98)
                    .opacity(0.5)
                
                // Placeholder avatar; later can be replaced with async image if available
                Circle()
                    .fill(Color(.secondarySystemBackground))
                    .frame(width: 92, height: 92)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .padding(14)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
            .padding(.top, 8)
            
            VStack(spacing: 2) {
                Text((auth.username ?? "").isEmpty ? "Your Name" : auth.username!)
                    .font(.title2).fontWeight(.bold)
                Text(auth.currentEmail ?? "")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .multilineTextAlignment(.center)
            
            HStack(spacing: 10) {
                // Quick action: Edit name
                Button {
                    editingField = .name
                } label: {
                    Label("Edit Name", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
                
                // Quick action: Edit email
                Button {
                    editingField = .email
                } label: {
                    Label("Edit Email", systemImage: "envelope")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 8)
    }
    
    // MARK: - Helper profile row
    @ViewBuilder
    func profileRow(label: String, value: String, editable: EditableField) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(value.isEmpty ? "Not set" : value)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
            Spacer()
            Button {
                editingField = editable
            } label: {
                Image(systemName: "square.and.pencil")
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(Color(.tertiarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
    
    // MARK: - Profile helpers

    private func currentValue(for field: EditableField) -> String {
        switch field {
        case .name:   return auth.username ?? ""
        case .email:  return auth.currentEmail ?? ""
        case .age:    return auth.age ?? ""
        case .health: return auth.healthIssues ?? ""
        }
    }

    private func saveProfileField(_ field: EditableField, newValue: String) {
        guard auth.isSignedIn else { return }
        Task {
            do {
                switch field {
                case .name:
                    try await auth.updateProfile(username: newValue)
                case .email:
                    try await auth.updateProfile(email: newValue)
                case .age:
                    try await auth.updateProfile(age: Int(newValue))
                case .health:
                    try await auth.updateProfile(healthIssues: newValue)
                }
                profileError = nil
            } catch {
                profileError = error.localizedDescription
            }
        }
    }
}

// Inline sheet for editing fields
struct EditFieldSheet: View {
    let field: ProfileView.EditableField
    let initialValue: String
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var draft: String = ""
    @FocusState private var textFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField(fieldName, text: $draft)
                    .focused($textFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("Edit \(fieldName)")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(draft)
                    }
                    .fontWeight(.bold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .onAppear {
                draft = initialValue
                textFocused = true
            }
        }
    }
    private var fieldName: String {
        switch field {
        case .name: return "Name"
        case .email: return "Email"
        case .age: return "Age"
        case .health: return "Health Issues"
        }
    }
}

