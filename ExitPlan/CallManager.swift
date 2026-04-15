import Foundation
import CallKit
import AVFoundation
import UIKit

final class CallManager: NSObject, ObservableObject, CXProviderDelegate {
    static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCallUUID: UUID?
    private var pendingCallTask: Task<Void, Never>?

    @Published var isCallActive     = false
    @Published var activeCallerName = ""
    @Published var callStartTime: Date? = nil

    override init() {
        let config = CXProviderConfiguration(localizedName: "mobile")
        config.supportsVideo            = false
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes     = [.phoneNumber]

        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: .main)
    }

    // MARK: - Public

    /// Triggers a fake incoming call after `delay` seconds.
    /// Uses UIBackgroundTask so it fires reliably even when the screen is locked.
    func triggerFakeCall(from contact: Contact, delay: TimeInterval) {
        pendingCallTask?.cancel()

        let name  = contact.name
        let phone = contact.phoneNumber

        // Ask iOS for up to 30 s of background execution time
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "ExitPlanFakeCall") {
            UIApplication.shared.endBackgroundTask(bgTask)
        }

        pendingCallTask = Task { @MainActor in
            defer { UIApplication.shared.endBackgroundTask(bgTask) }

            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            self.reportIncomingCallNow(name: name, phone: phone)
        }
    }

    func cancelPendingCall() {
        pendingCallTask?.cancel()
        pendingCallTask = nil
    }

    // Called directly (delay = 0) when the sequence is managed externally (e.g. ComboManager)
    @MainActor
    func reportIncomingCallNow(name: String, phone: String) {
        let uuid = UUID()
        activeCallUUID   = uuid
        activeCallerName = name

        let update = CXCallUpdate()
        update.remoteHandle        = CXHandle(type: .phoneNumber, value: phone)
        update.localizedCallerName = name
        update.hasVideo            = false
        update.supportsHolding     = true
        update.supportsGrouping    = false
        update.supportsUngrouping  = false
        update.supportsDTMF        = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error { print("CallKit error: \(error)") }
        }
    }

    func endCall() {
        guard let uuid = activeCallUUID else { return }
        callController.request(CXTransaction(action: CXEndCallAction(call: uuid))) { _ in }
    }

    // MARK: - CXProviderDelegate

    func providerDidReset(_ provider: CXProvider) {
        activeCallUUID = nil
        isCallActive   = false
        callStartTime  = nil
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        configureAudioSession()
        isCallActive  = true
        callStartTime = Date()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        activeCallUUID = nil
        isCallActive   = false
        callStartTime  = nil
        deactivateAudioSession()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {}
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {}

    // MARK: - Audio Session

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { print("Audio session error: \(error)") }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
