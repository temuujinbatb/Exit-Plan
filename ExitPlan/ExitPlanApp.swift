import SwiftUI

@main
struct ExitPlanApp: App {
    @StateObject private var callManager            = CallManager.shared
    @StateObject private var notificationManager    = NotificationManager.shared
    @StateObject private var contactStore           = ContactStore.shared
    @StateObject private var messageTemplateStore   = MessageTemplateStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(callManager)
                .environmentObject(notificationManager)
                .environmentObject(contactStore)
                .environmentObject(messageTemplateStore)
                .task { await notificationManager.requestPermission() }
        }
    }
}
