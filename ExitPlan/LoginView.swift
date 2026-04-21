import SwiftUI
import GoogleSignInSwift

// MARK: - Auth Mode

private enum AuthMode { case signIn, register }

// MARK: - LoginView

struct LoginView: View {
    @StateObject private var auth = AuthManager.shared

    @State private var mode: AuthMode    = .signIn
    @State private var email            = ""
    @State private var password         = ""
    @State private var confirmPassword  = ""
    @State private var showPassword     = false
    @FocusState private var focus: Field?

    private enum Field { case email, password, confirm }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.27, green: 0.82, blue: 0.39),
                         Color(red: 0.11, green: 0.67, blue: 0.24)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {

                    // Logo area
                    VStack(spacing: 8) {
                        Image(systemName: "phone.arrow.down.left.fill")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Exit Plan")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.white)
                        Text("Your emergency escape button")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.top, 64)
                    .padding(.bottom, 40)

                    // Card
                    VStack(spacing: 20) {

                        // Mode toggle
                        Picker("", selection: $mode) {
                            Text("Sign In").tag(AuthMode.signIn)
                            Text("Register").tag(AuthMode.register)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 4)

                        // Fields
                        VStack(spacing: 12) {
                            InputField(
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

                            InputField(
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
                                InputField(
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
                                .foregroundStyle(msg.contains("sent") ? .green : .red)
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
                                    .fill(Color.green)
                                if auth.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(mode == .signIn ? "Sign In" : "Create Account")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(height: 52)
                        }
                        .disabled(auth.isLoading || !isFormValid)

                        // Forgot password (sign in only)
                        if mode == .signIn {
                            Button {
                                Task { await auth.resetPassword(email: email) }
                            } label: {
                                Text("Forgot password?")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Divider
                        HStack {
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                            Text("or").font(.caption).foregroundStyle(.secondary)
                            Rectangle().frame(height: 1).foregroundStyle(.quaternary)
                        }

                        // Google Sign-In
                        Button {
                            Task { await auth.signInWithGoogle() }
                        } label: {
                            HStack(spacing: 10) {
                                Image("google_logo") // add asset, or use text fallback below
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                                Text("Continue with Google")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color(.systemGray4), lineWidth: 1)
                            )
                        }
                        .disabled(auth.isLoading)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 28))
                    .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
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

// MARK: - Input Field

private struct InputField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool
    @Binding var showSecret: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            if isSecure && !showSecret {
                SecureField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }

            if isSecure {
                Button {
                    showSecret.toggle()
                } label: {
                    Image(systemName: showSecret ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
