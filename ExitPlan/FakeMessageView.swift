import Foundation
import UIKit
import UserNotifications

// MARK: - Combo Manager

final class ComboManager: ObservableObject {
    static let shared = ComboManager()

    @Published var isRunning = false

    private var pendingNotifIDs: [String] = []
    private var callTask: Task<Void, Never>?

    /// Schedules message notifications (system-managed) and triggers the fake call
    /// via a background task so the full sequence runs even when the screen is locked.
    func trigger(
        contact: Contact,
        templates: [MessageTemplate],
        messageCount: Int,
        firstMessageDelay: TimeInterval,
        messageInterval: TimeInterval,
        delayBeforeCall: TimeInterval
    ) {
        cancel()
        guard !templates.isEmpty else { return }
        isRunning = true

        let count    = min(messageCount, templates.count)
        let selected = Array(templates.prefix(count))
        var ids: [String] = []

        // Pre-schedule every message notification through the system scheduler —
        // these fire reliably regardless of app state.
        for (i, template) in selected.enumerated() {
            let delay = firstMessageDelay + Double(i) * messageInterval
            let id = NotificationManager.shared.scheduleNotification(
                contactName: contact.name,
                messageText: template.text,
                delay: delay
            )
            ids.append(id)
        }
        pendingNotifIDs = ids

        // Trigger the call via Task.sleep + UIBackgroundTask (works up to ~30 s background time)
        let callDelay = firstMessageDelay + Double(count - 1) * messageInterval + delayBeforeCall

        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ExitPlanCombo") {
            UIApplication.shared.endBackgroundTask(bgTask)
        }

        let name  = contact.name
        let phone = contact.phoneNumber

        callTask = Task { @MainActor in
            defer { UIApplication.shared.endBackgroundTask(bgTask) }

            try? await Task.sleep(nanoseconds: UInt64(callDelay * 1_000_000_000))

            guard !Task.isCancelled else {
                isRunning = false
                return
            }

            CallManager.shared.reportIncomingCallNow(name: name, phone: phone)
            isRunning = false
        }
    }

    func cancel() {
        callTask?.cancel()
        callTask = nil

        if !pendingNotifIDs.isEmpty {
            UNUserNotificationCenter.current()
                .removePendingNotificationRequests(withIdentifiers: pendingNotifIDs)
            pendingNotifIDs = []
        }

        CallManager.shared.cancelPendingCall()
        isRunning = false
    }
}
