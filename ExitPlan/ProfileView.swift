import SwiftUI
import FirebaseAuth

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager:          AuthManager
    @EnvironmentObject var contactStore:         ContactStore
    @EnvironmentObject var messageTemplateStore: MessageTemplateStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss

    @State private var showChangePassword = false
    @State private var showDeleteAccount  = false
    @State private var showLegal          = false

    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    private var initials: String {
        String((authManager.user?.email ?? "?").prefix(1)).uppercased()
    }

    var body: some View {
        EPScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header row
                    HStack {
                        Text("Profile")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(t.ink)
                        Spacer()
                        EPCircleButton(size: 38, accent: false, action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(t.inkSoft)
                        }
                    }
                    .padding(.top, 8)

                    // Avatar + email card
                    EPCard(padding: 20) {
                        HStack(spacing: 16) {
                            EPAvatar(name: initials, size: 56)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.user?.email ?? "—")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(t.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Text("Exit Plan member")
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.inkFaint)
                            }
                            Spacer()
                        }
                    }

                    // Manage
                    EPCard(padding: 16) {
                        EPLabel(text: "Manage")
                        Spacer().frame(height: 12)
                        VStack(spacing: 8) {
                            NavigationLink {
                                ContactsEditView().environmentObject(contactStore)
                            } label: {
                                profileRow(icon: "person.2.fill", label: "Contacts")
                            }
                            .buttonStyle(.plain)

                            Divider().opacity(0.3)

                            NavigationLink {
                                MessagesEditView().environmentObject(messageTemplateStore)
                            } label: {
                                profileRow(icon: "text.bubble.fill", label: "Messages")
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Security
                    EPCard(padding: 16) {
                        EPLabel(text: "Security")
                        Spacer().frame(height: 12)
                        VStack(spacing: 8) {
                            Button { showChangePassword = true } label: {
                                profileRow(icon: "lock.rotation", label: "Change Password")
                            }
                            .buttonStyle(.plain)

                            Divider().opacity(0.3)

                            Button { showDeleteAccount = true } label: {
                                profileRow(icon: "person.crop.circle.badge.minus", label: "Delete Account", destructive: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Legal
                    EPCard(padding: 16) {
                        EPLabel(text: "Legal")
                        Spacer().frame(height: 12)
                        Button { showLegal = true } label: {
                            profileRow(icon: "doc.text", label: "Terms & Privacy")
                        }
                        .buttonStyle(.plain)
                    }

                    // Sign Out
                    Button {
                        authManager.signOut()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.red.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(t.bg)
                                .shadow(color: t.shadowDark,  radius: 8, x: 6, y: 6)
                                .shadow(color: t.shadowLight, radius: 8, x: -6, y: -6)
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet()
                .environmentObject(authManager)
        }
        .alert("Delete Account", isPresented: $showDeleteAccount) {
            DeleteAccountAlert()
                .environmentObject(authManager)
        } message: {
            Text("This will permanently delete your account and all local data. This cannot be undone.")
        }
        .sheet(isPresented: $showLegal) {
            LegalView()
        }
    }

    // MARK: - Profile Row

    private func profileRow(icon: String, label: String, destructive: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(destructive ? .red.opacity(0.8) : Color.epAccentDeep)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(destructive ? .red.opacity(0.8) : t.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(t.inkFaint)
        }
        .padding(.vertical, 4)
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
            UserDefaults.standard.removeObject(forKey: "contacts_v2")
            UserDefaults.standard.removeObject(forKey: "message_templates_v2")
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
            "By using Exit Plan (the App), you agree to these terms. The App is intended for personal use as a social escape tool. You agree not to use the App to deceive emergency services, harass others, or engage in any unlawful activity. Misuse of the App is solely your responsibility."
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
