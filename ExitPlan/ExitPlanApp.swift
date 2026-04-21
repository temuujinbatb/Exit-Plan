import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct ExitPlanApp: App {
    @StateObject private var callManager          = CallManager.shared
    @StateObject private var notificationManager  = NotificationManager.shared
    @StateObject private var contactStore         = ContactStore.shared
    @StateObject private var messageTemplateStore = MessageTemplateStore.shared
    @StateObject private var authManager          = AuthManager.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    ContentView()
                        .environmentObject(callManager)
                        .environmentObject(notificationManager)
                        .environmentObject(contactStore)
                        .environmentObject(messageTemplateStore)
                        .environmentObject(authManager)
                        .task { await notificationManager.requestPermission() }
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
