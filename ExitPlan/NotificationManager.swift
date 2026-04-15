import Foundation
import UserNotifications

final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var isPermissionGranted = false

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermission()
    }

    // MARK: - Permission

    func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run { isPermissionGranted = granted }
        } catch {
            print("Notification permission error: \(error)")
        }
    }

    func checkPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isPermissionGranted = settings.authorizationStatus == .authorized
            }
        }
    }

    // MARK: - Schedule

    /// Schedules a message notification. Returns the request identifier (for cancellation).
    @discardableResult
    func scheduleNotification(
        contactName: String,
        messageText: String,
        delay: TimeInterval
    ) -> String {
        let content = UNMutableNotificationContent()
        content.title             = contactName
        content.body              = messageText
        content.sound             = .default
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier  = "exit-plan-\(contactName)"

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(delay, 1),
            repeats: false
        )
        let id = UUID().uuidString
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error { print("Notification error: \(error)") }
        }
        return id
    }

    func cancelNotification(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Show banner + play sound even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
