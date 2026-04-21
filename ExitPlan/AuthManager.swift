import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var user: FirebaseAuth.User? = nil
    @Published var isLoading                = false
    @Published var errorMessage: String?    = nil

    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async { self?.user = user }
        }
    }

    deinit {
        if let h = authHandle { Auth.auth().removeStateDidChangeListener(h) }
    }

    var isLoggedIn: Bool { user != nil }

    // MARK: - Email / Password

    func signIn(email: String, password: String) async {
        await setLoading(true)
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            await setError(error.localizedDescription)
        }
        await setLoading(false)
    }

    func register(email: String, password: String) async {
        await setLoading(true)
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            await setError(error.localizedDescription)
        }
        await setLoading(false)
    }

    func resetPassword(email: String) async {
        await setLoading(true)
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await setError("Password reset email sent.")
        } catch {
            await setError(error.localizedDescription)
        }
        await setLoading(false)
    }

    // MARK: - Google

    func signInWithGoogle() async {
        await setLoading(true)

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            await setError("Firebase not configured.")
            await setLoading(false)
            return
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        // UIApplication must be accessed on the main thread
        let rootVC: UIViewController? = await MainActor.run {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.windows.first?.rootViewController
        }

        guard let rootVC else {
            await setLoading(false)
            return
        }

        do {
            let result    = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else { throw AuthError.missingToken }
            let credential = GoogleAuthProvider.credential(
                withIDToken:   idToken,
                accessToken:   result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        } catch {
            await setError(error.localizedDescription)
        }
        await setLoading(false)
    }

    // MARK: - Sign Out

    func signOut() {
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: - Helpers

    @MainActor private func setLoading(_ val: Bool) { isLoading = val }
    @MainActor private func setError(_ msg: String)  { errorMessage = msg }
}

private enum AuthError: Error { case missingToken }
