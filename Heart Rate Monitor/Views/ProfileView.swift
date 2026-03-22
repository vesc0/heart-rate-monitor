import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @State private var showAuthSheet = false
    @State private var selectedAuthTab = 0 // 0 = Login, 1 = Sign Up
    @State private var editingField: EditableField? = nil
    @State private var profileError: String?

    enum EditableField: String, CaseIterable, Identifiable {
        case name, email, age, gender, height, weight, health
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            Group {
                if auth.isSignedIn {
                    ScrollView {
                        signedInContent
                    }
                } else {
                    signedOutContent
                }
            }
            .if(!auth.isSignedIn) { view in
                view
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .background(Color(.systemGroupedBackground))
            }
            .if(auth.isSignedIn) { view in
                view
                    .scrollDismissesKeyboard(.interactively)
                    .background(Color(.systemGroupedBackground))
            }
            .sheet(isPresented: $showAuthSheet) {
                AuthSheetView(selectedTab: $selectedAuthTab)
                    .environmentObject(auth)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled(false)
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
            .onChange(of: auth.isSignedIn) { _, isSignedIn in
                if isSignedIn {
                    showAuthSheet = false
                    profileError = nil
                }
            }
            .navigationTitle("Profile")
        }
    }

    // MARK: - Signed Out

    private var signedOutContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.secondary.opacity(0.5))

            VStack(spacing: 8) {
                Text("Welcome")
                    .font(.title2).fontWeight(.bold)
                Text("Log in to sync your measurements,\nview stats, and manage your profile.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }

            Button {
                selectedAuthTab = 0
                showAuthSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text("Log In or Sign Up")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .padding()
    }

    // MARK: - Signed In

    private var signedInContent: some View {
        VStack(spacing: 20) {
            profileHeaderCard
                .padding(.top, 8)

            // Details section
            VStack(alignment: .leading, spacing: 10) {
                Text("Details")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 6)

                VStack(spacing: 0) {
                    profileRow(icon: "person.fill", label: "Name", value: auth.username ?? "", editable: .name)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "envelope.fill", label: "Email", value: auth.currentEmail ?? "", editable: .email)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "calendar", label: "Age", value: auth.age ?? "", editable: .age)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "figure.stand", label: "Gender", value: auth.gender ?? "", editable: .gender)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "ruler", label: "Height (cm)", value: auth.heightCm ?? "", editable: .height)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "scalemass", label: "Weight (kg)", value: auth.weightKg ?? "", editable: .weight)
                    Divider().padding(.leading, 48)
                    profileRow(icon: "heart.text.clipboard", label: "Health", value: auth.healthIssues ?? "", editable: .health)
                }
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if let err = profileError {
                Text(err)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }

            // Sign out
            Button(role: .destructive) {
                let gen = UINotificationFeedbackGenerator()
                gen.notificationOccurred(.warning)
                auth.signOut()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(.horizontal)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Header Card

    private var profileHeaderCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            gradient: Gradient(colors: [.pink, .red, .orange, .pink]),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 94, height: 94)
                    .opacity(0.6)

                Circle()
                    .fill(Color(.tertiarySystemGroupedBackground))
                    .frame(width: 86, height: 86)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                            .padding(12)
                    )
            }
            .padding(.top, 12)

            VStack(spacing: 4) {
                Text((auth.username ?? "").isEmpty ? "Your Name" : auth.username!)
                    .font(.title3).fontWeight(.bold)
                Text(auth.currentEmail ?? "")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Profile Row

    @ViewBuilder
    func profileRow(icon: String, label: String, value: String, editable: EditableField) -> some View {
        Button {
            editingField = editable
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value.isEmpty ? "Not set" : value)
                        .font(.body)
                        .foregroundColor(value.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Profile helpers

    private func currentValue(for field: EditableField) -> String {
        switch field {
        case .name:   return auth.username ?? ""
        case .email:  return auth.currentEmail ?? ""
        case .age:    return auth.age ?? ""
        case .gender: return auth.gender ?? ""
        case .height: return auth.heightCm ?? ""
        case .weight: return auth.weightKg ?? ""
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
                case .gender:
                    try await auth.updateProfile(gender: newValue.lowercased())
                case .height:
                    try await auth.updateProfile(heightCm: Int(newValue))
                case .weight:
                    try await auth.updateProfile(weightKg: Int(newValue))
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

// MARK: - Auth Sheet (presented as .sheet — handles keyboard natively)

struct AuthSheetView: View {
    @EnvironmentObject private var auth: AuthViewModel
    @Binding var selectedTab: Int

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Log In").tag(0)
                    Text("Sign Up").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)
                .padding(.bottom, 12)

                ScrollView {
                    if selectedTab == 0 {
                        LoginView(inPopup: true)
                            .environmentObject(auth)
                            .padding(.horizontal)
                    } else {
                        SignUpView(inPopup: true)
                            .environmentObject(auth)
                            .padding(.horizontal)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(selectedTab == 0 ? "Log In" : "Sign Up")
            .navigationBarTitleDisplayMode(.inline)
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
        case .name:   return "Name"
        case .email:  return "Email"
        case .age:    return "Age"
        case .gender: return "Gender"
        case .height: return "Height (cm)"
        case .weight: return "Weight (kg)"
        case .health: return "Health Issues"
        }
    }
}

