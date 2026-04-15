import AppIntents

// MARK: - Fake Call

struct TriggerFakeCallIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Fake Call"
    static var description = IntentDescription("Triggers a fake incoming call.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults = UserDefaults.standard
        let idStr    = defaults.string(forKey: "selectedContactID") ?? ""
        let contact  = resolveContact(idStr: idStr)
        let delay    = max(defaults.double(forKey: "triggerDelay"), 3.0)

        CallManager.shared.triggerFakeCall(from: contact, delay: delay)
        return .result()
    }
}

// MARK: - Fake Message (notification)

struct TriggerFakeMessageIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Fake Message"
    static var description = IntentDescription("Sends a fake urgent notification message.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults    = UserDefaults.standard
        let idStr       = defaults.string(forKey: "selectedContactID") ?? ""
        let templateStr = defaults.string(forKey: "selectedTemplateID") ?? ""
        let delay       = max(defaults.double(forKey: "triggerDelay"), 3.0)

        let contact  = resolveContact(idStr: idStr)
        let template = resolveTemplate(idStr: templateStr)

        NotificationManager.shared.scheduleNotification(
            contactName: contact.name,
            messageText: template.text,
            delay: delay
        )
        return .result()
    }
}

// MARK: - Combo

struct TriggerComboIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Combo Escape"
    static var description = IntentDescription("Sends escalating messages then triggers a fake call.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        let defaults       = UserDefaults.standard
        let idStr          = defaults.string(forKey: "selectedContactID") ?? ""
        let contact        = resolveContact(idStr: idStr)
        let messageCount       = defaults.integer(forKey: "comboMessageCount") > 0
                                 ? defaults.integer(forKey: "comboMessageCount") : 3
        let firstMessageDelay  = defaults.double(forKey: "comboFirstMessageDelay") > 0
                                 ? defaults.double(forKey: "comboFirstMessageDelay") : 5.0
        let interval           = defaults.double(forKey: "comboMessageInterval") > 0
                                 ? defaults.double(forKey: "comboMessageInterval") : 10.0
        let callDelay          = defaults.double(forKey: "comboDelayBeforeCall") > 0
                                 ? defaults.double(forKey: "comboDelayBeforeCall") : 10.0
        let templates          = MessageTemplateStore.shared.templates

        ComboManager.shared.trigger(
            contact: contact,
            templates: templates,
            messageCount: messageCount,
            firstMessageDelay: firstMessageDelay,
            messageInterval: interval,
            delayBeforeCall: callDelay
        )
        return .result()
    }
}

// MARK: - App Shortcuts

struct ExitPlanShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TriggerFakeCallIntent(),
            phrases: ["Fake call with \(.applicationName)", "Exit plan call \(.applicationName)"],
            shortTitle: "Fake Call",
            systemImageName: "phone.arrow.down.left"
        )
        AppShortcut(
            intent: TriggerFakeMessageIntent(),
            phrases: ["Fake message with \(.applicationName)", "Exit plan message \(.applicationName)"],
            shortTitle: "Fake Message",
            systemImageName: "message.badge"
        )
        AppShortcut(
            intent: TriggerComboIntent(),
            phrases: ["Combo escape with \(.applicationName)", "Exit plan combo \(.applicationName)"],
            shortTitle: "Combo Escape",
            systemImageName: "bolt.fill"
        )
    }
}

// MARK: - Helpers

private func resolveContact(idStr: String) -> Contact {
    let id = UUID(uuidString: idStr)
    return ContactStore.shared.contacts.first(where: { $0.id == id })
        ?? ContactStore.shared.contacts.first
        ?? Contact(name: "Mom", phoneNumber: "+1 (555) 867-5309")
}

private func resolveTemplate(idStr: String) -> MessageTemplate {
    let id = UUID(uuidString: idStr)
    return MessageTemplateStore.shared.templates.first(where: { $0.id == id })
        ?? MessageTemplateStore.shared.templates.first
        ?? MessageTemplate(text: "Call me back immediately.")
}
