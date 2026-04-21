import SwiftUI
import FirebaseAuth

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager:          AuthManager
    @EnvironmentObject var contactStore:         ContactStore
    @EnvironmentObject var messageTemplateStore: MessageTemplateStore

    @State private var showChangePassword = false
    @State private var showDeleteAccount  = false
    @State private var showLegal          = false

    var body: some View {
        List {
            // ── User info ──────────────────────────────────────────────
            Section {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.green, Color(red: 0.1, green: 0.6, blue: 0.2)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ))
                            .frame(width: 56, height: 56)
                        Text(initials)
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(authManager.user?.email ?? "—")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text("Exit Plan member")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // ── Manage ─────────────────────────────────────────────────
            Section("Manage") {
                NavigationLink("Contacts") {
                    ContactsEditView().environmentObject(contactStore)
                }
                NavigationLink("Messages") {
                    MessagesEditView().environmentObject(messageTemplateStore)
                }
            }

            // ── Security ───────────────────────────────────────────────
            Section("Security") {
                Button {
                    showChangePassword = true
                } label: {
                    Label("Change Password", systemImage: "lock.rotation")
                        .foregroundStyle(.primary)
                }

                Button(role: .destructive) {
                    showDeleteAccount = true
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                }
            }

            // ── Legal ──────────────────────────────────────────────────
            Section("Legal") {
                Button {
                    showLegal = true
                } label: {
                    Label("Terms & Privacy", systemImage: "doc.text")
                        .foregroundStyle(.primary)
                }
            }

            // ── Sign Out ───────────────────────────────────────────────
            Section {
                Button(role: .destructive) {
                    authManager.signOut()
                } label: {
                    HStack {
                        Spacer()
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .font(.headline)
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
        }
        .alert("Delete Account", isPresented: $showDeleteAccount) {
            DeleteAccountAlert()
        } message: {
            Text("This will permanently delete your account and all local data. This cannot be undone.")
        }
        .sheet(isPresented: $showLegal) {
            LegalView()
        }
    }

    private var initials: String {
        let email = authManager.user?.email ?? ""
        return String(email.prefix(1)).uppercased()
    }
}

// MARK: - Change Password Sheet

struct ChangePasswordSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword     = ""
    @State private var confirmPassword = ""
    @State private var isLoading       = false
    @State private var message: String?
    @State private var isSuccess       = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Password") {
                    SecureField("Enter current password", text: $currentPassword)
                }
                Section("New Password") {
                    SecureField("New password (min 6 chars)", text: $newPassword)
                    SecureField("Confirm new password", text: $confirmPassword)
                }
                if let msg = message {
                    Section {
                        Text(msg)
                            .foregroundStyle(isSuccess ? .green : .red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await changePassword() } }
                        .disabled(isLoading || !isFormValid)
                }
            }
            .overlay {
                if isLoading { ProgressView() }
            }
        }
    }

    private var isFormValid: Bool {
        !currentPassword.isEmpty && newPassword.count >= 6 && newPassword == confirmPassword
    }

    private func changePassword() async {
        guard let user  = Auth.auth().currentUser,
              let email = user.email else { return }
        isLoading = true
        message   = nil

        do {
            // Re-authenticate first (Firebase requires it for sensitive ops)
            let credential = EmailAuthProvider.credential(withEmail: email, password: currentPassword)
            try await user.reauthenticate(with: credential)
            try await user.updatePassword(to: newPassword)
            isSuccess = true
            message   = "Password updated successfully."
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { dismiss() }
        } catch {
            isSuccess = false
            message   = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Delete Account Alert Buttons

struct DeleteAccountAlert: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        SecureField("Enter your password to confirm", text: $password)
        Button("Delete Everything", role: .destructive) {
            Task { await deleteAccount() }
        }
        Button("Cancel", role: .cancel) { }
    }

    private func deleteAccount() async {
        guard let user  = Auth.auth().currentUser,
              let email = user.email else { return }
        do {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            try await user.reauthenticate(with: credential)

            // Wipe local data
            UserDefaults.standard.removeObject(forKey: "contacts_v2")
            UserDefaults.standard.removeObject(forKey: "message_templates_v2")

            // Delete Firebase account
            try await user.delete()
            authManager.signOut()
        } catch {
            print("Delete account error: \(error)")
        }
    }
}

// MARK: - Legal View

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(legalSections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("Terms & Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var legalSections: [(title: String, body: String)] {[
        (
            "Terms of Use",
            "By using Exit Plan ("the App"), you agree to these terms. The App is intended for personal use as a social escape tool. You agree not to use the App to deceive emergency services, harass others, or engage in any unlawful activity. Misuse of the App is solely your responsibility."
        ),
        (
            "No Emergency Use",
            "Exit Plan is not a substitute for emergency services. In a genuine emergency, always contact your local emergency services (911, 112, or your regional equivalent) directly. The fake call and message features are strictly for social situations."
        ),
        (
            "Your Data — Stored Locally Only",
            "Exit Plan does not collect, transmit, or store your contacts or message templates on any server or cloud service. All contacts and messages you add are stored exclusively on your device using local storage (UserDefaults). We have no access to this data, and it is never shared with third parties."
        ),
        (
            "Account Data",
            "If you create an account, your email address is stored securely via Firebase Authentication (Google). This is used solely for authentication purposes. We do not sell, share, or use your email for marketing without your explicit consent."
        ),
        (
            "Contact Permissions",
            "If you choose to import contacts from your device, Exit Plan accesses your contacts only at the moment of import. The selected contact information is stored locally on your device. We do not upload or retain your contacts anywhere outside your device."
        ),
        (
            "Intellectual Property",
            "All content, design, and code within Exit Plan is the property of the developer. You may not copy, modify, or distribute any part of the App without written permission."
        ),
        (
            "Disclaimer of Warranties",
            "Exit Plan is provided \"as is\" without warranties of any kind. The developer makes no guarantees regarding the reliability, availability, or accuracy of the App and is not liable for any damages arising from its use."
        ),
        (
            "Changes to Terms",
            "These terms may be updated from time to time. Continued use of the App after changes constitutes acceptance of the new terms."
        ),
        (
            "Contact",
            "For questions about these terms or your data, contact us through the App Store listing."
        ),
        (
            "Last Updated",
            "April 2026"
        )
    ]}
}
