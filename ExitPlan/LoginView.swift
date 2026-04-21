import SwiftUI
import GoogleSignInSwift

// MARK: - Auth Mode

private enum AuthMode { case signIn, register }

// MARK: - LoginView

struct LoginView: View {
    @StateObject private var auth = AuthManager.shared
    @Environment(\.colorScheme) private var scheme

    @State private var mode: AuthMode    = .signIn
    @State private var email            = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var showPassword     = false
    @FocusState private var focus: Field?

    private enum Field { case email, password, confirm }

    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        EPScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // Logo area
                    VStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(t.bg)
                                .shadow(color: t.shadowDark,  radius: 14, x: 10, y: 10)
                                .shadow(color: t.shadowLight, radius: 14, x: -10, y: -10)
                                .frame(width: 88, height: 88)
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.epAccent, .epAccentDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 68, height: 68)
                            Image(systemName: "phone.arrow.down.left.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.bottom, 6)

                        Text("EXIT PLAN")
                            .font(.system(size: 13, weight: .semibold))
                            .tracking(4)
                            .foregroundStyle(t.inkFaint)
                        Text("Your emergency escape")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(t.ink)
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 36)

                    // Card
                    EPCard(radius: 26, padding: 24) {
                        VStack(spacing: 20) {

                            // Mode toggle
                            EPSegmented(
                                selection: Binding(
                                    get: { mode == .signIn ? "signIn" : "register" },
                                    set: { mode = $0 == "signIn" ? .signIn : .register }
                                ),
                                options: [
                                    (value: "signIn",   label: "Sign In",  icon: "person.fill"),
                                    (value: "register", label: "Register", icon: "person.badge.plus")
                                ]
                            )
                            .animation(.spring(response: 0.3), value: mode)

                            // Fields
                            VStack(spacing: 12) {
                                NEUField(
                                    icon: "envelope.fill",
                                    placeholder: "Email",
                                    text: $email,
                                    keyboardType: .emailAddress,
                                    isSecure: false,
                                    showSecret: .constant(false)
                                )
                                .focused($focus, equals: .email)
                                .submitLabel(.next)
                                .onSubmit { focus = .password }

                                NEUField(
                                    icon: "lock.fill",
                                    placeholder: "Password",
                                    text: $password,
                                    keyboardType: .default,
                                    isSecure: true,
                                    showSecret: $showPassword
                                )
                                .focused($focus, equals: .password)
                                .submitLabel(mode == .register ? .next : .go)
                                .onSubmit {
                                    if mode == .register { focus = .confirm }
                                    else { Task { await signIn() } }
                                }

                                if mode == .register {
                                    NEUField(
                                        icon: "lock.rotation",
                                        placeholder: "Confirm Password",
                                        text: $confirmPassword,
                                        keyboardType: .default,
                                        isSecure: true,
                                        showSecret: $showPassword
                                    )
                                    .focused($focus, equals: .confirm)
                                    .submitLabel(.go)
                                    .onSubmit { Task { await register() } }
                                    .transition(.move(edge: .top).combined(with: .opacity))
                                }
                            }
                            .animation(.default, value: mode)

                            // Error / info message
                            if let msg = auth.errorMessage {
                                Text(msg)
                                    .font(.caption)
                                    .foregroundStyle(msg.contains("sent") ? Color.epAccentDeep : Color.red)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity)
                            }

                            // Primary button
                            Button {
                                Task {
                                    if mode == .signIn { await signIn() }
                                    else { await register() }
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(LinearGradient(
                                            colors: [.epAccent, .epAccentDeep],
                                            startPoint: .leading, endPoint: .trailing))
                                        .shadow(color: Color.epAccentDeep.opacity(0.4), radius: 8, y: 4)
                                    if auth.isLoading {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text(mode == .signIn ? "Sign In" : "Create Account")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .frame(height: 52)
                            }
                            .buttonStyle(.plain)
                            .disabled(auth.isLoading || !isFormValid)
                            .opacity(auth.isLoading || !isFormValid ? 0.6 : 1.0)

                            // Forgot password
                            if mode == .signIn {
                                Button {
                                    Task { await auth.resetPassword(email: email) }
                                } label: {
                                    Text("Forgot password?")
                                        .font(.system(size: 13))
                                        .foregroundStyle(t.inkFaint)
                                }
                                .buttonStyle(.plain)
                            }

                            // Divider
                            HStack(spacing: 12) {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(t.inkFaint.opacity(0.3))
                                Text("or")
                                    .font(.system(size: 12))
                                    .foregroundStyle(t.inkFaint)
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(t.inkFaint.opacity(0.3))
                            }

                            // Google Sign-In
                            Button {
                                Task { await auth.signInWithGoogle() }
                            } label: {
                                HStack(spacing: 10) {
                                    Image("google_logo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 20, height: 20)
                                    Text("Continue with Google")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(t.ink)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(t.bgDeep)
                                        .shadow(color: t.shadowDark,  radius: 5, x: 4, y: 4)
                                        .shadow(color: t.shadowLight, radius: 5, x: -4, y: -4)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(auth.isLoading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .onChange(of: mode) { _, _ in
            auth.errorMessage = nil
            confirmPassword   = ""
        }
    }

    // MARK: - Helpers

    private var isFormValid: Bool {
        let emailOK = email.contains("@") && email.contains(".")
        let passOK  = password.count >= 6
        if mode == .register {
            return emailOK && passOK && confirmPassword == password
        }
        return emailOK && passOK
    }

    private func signIn() async {
        focus = nil
        await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
    }

    private func register() async {
        guard password == confirmPassword else {
            auth.errorMessage = "Passwords do not match."
            return
        }
        focus = nil
        await auth.register(email: email.trimmingCharacters(in: .whitespaces), password: password)
    }
}

// MARK: - Neumorphic Input Field

private struct NEUField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    @Binding var showSecret: Bool

    @Environment(\.colorScheme) private var scheme
    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(t.inkFaint)
                .frame(width: 18)

            if isSecure && !showSecret {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(t.ink)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .foregroundStyle(t.ink)
            }

            if isSecure {
                Button {
                    showSecret.toggle()
                } label: {
                    Image(systemName: showSecret ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(t.inkFaint)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(t.bgDeep)
                .shadow(color: t.shadowDark,  radius: 3, x:  2, y:  2)
                .shadow(color: t.shadowLight, radius: 3, x: -2, y: -2)
        )
    }
}
