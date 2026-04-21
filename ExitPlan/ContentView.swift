import SwiftUI
import Contacts
import ContactsUI

// MARK: - Trigger Mode

enum TriggerMode: String, CaseIterable {
    case call    = "Call"
    case message = "Message"
    case combo   = "Combo"

    var icon: String {
        switch self {
        case .call:    return "phone.fill"
        case .message: return "bell.fill"
        case .combo:   return "bolt.fill"
        }
    }
}

// MARK: - ContentView

struct ContentView: View {
    @EnvironmentObject var callManager:          CallManager
    @EnvironmentObject var notificationManager:  NotificationManager
    @EnvironmentObject var contactStore:         ContactStore
    @EnvironmentObject var messageTemplateStore: MessageTemplateStore
    @EnvironmentObject var authManager:          AuthManager

    @AppStorage("triggerMode")              private var triggerModeRaw:          String = TriggerMode.call.rawValue
    @AppStorage("selectedContactID")        private var selectedContactID:       String = ""
    @AppStorage("selectedTemplateID")       private var selectedTemplateID:      String = ""
    @AppStorage("triggerDelay")             private var triggerDelay:            Double = 5.0
    @AppStorage("comboMessageCount")        private var comboMessageCount:       Int    = 3
    @AppStorage("comboFirstMessageDelay")   private var comboFirstMessageDelay:  Double = 5.0
    @AppStorage("comboMessageInterval")     private var comboMessageInterval:    Double = 10.0
    @AppStorage("comboDelayBeforeCall")     private var comboDelayBeforeCall:    Double = 10.0

    // In-call overlay
    @State private var showInCallView = false

    // Countdown state (call / message modes)
    @State private var countdownRemaining: Int? = nil    // nil = idle
    @State private var pendingNotifID: String?  = nil    // ID to cancel if user bails
    @State private var countdownTask: Task<Void, Never>? = nil

    @StateObject private var combo = ComboManager.shared

    private var mode: TriggerMode { TriggerMode(rawValue: triggerModeRaw) ?? .call }

    private var selectedContact: Contact {
        let id = UUID(uuidString: selectedContactID)
        return contactStore.contacts.first(where: { $0.id == id })
            ?? contactStore.contacts.first
            ?? Contact(name: "Mom", phoneNumber: "+1 (555) 867-5309")
    }

    private var selectedTemplate: MessageTemplate {
        let id = UUID(uuidString: selectedTemplateID)
        return messageTemplateStore.templates.first(where: { $0.id == id })
            ?? messageTemplateStore.templates.first
            ?? MessageTemplate(text: "Call me back immediately.")
    }

    var body: some View {
        NavigationStack {
            List {
                modePicker
                contactSection
                settingsSection
                triggerSection
                manageSection
                setupSection
            }
            .navigationTitle("Exit Plan")
            .animation(.default, value: triggerModeRaw)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink {
                        ProfileView()
                            .environmentObject(authManager)
                            .environmentObject(contactStore)
                            .environmentObject(messageTemplateStore)
                    } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        // In-call full-screen
        .fullScreenCover(isPresented: $showInCallView) {
            InCallView(onMinimize: { showInCallView = false })
                .environmentObject(callManager)
        }
        // In-call floating banner when minimized
        .safeAreaInset(edge: .bottom) {
            if callManager.isCallActive && !showInCallView {
                InCallBanner(onTap: { showInCallView = true })
                    .environmentObject(callManager)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: callManager.isCallActive) { _, active in
            if active {
                clearCountdown()        // countdown done, call fired
                showInCallView = true
            }
        }
        .onChange(of: triggerModeRaw) { _, _ in
            clearCountdown()            // reset when switching modes
        }
    }

    // MARK: - Mode Picker

    private var modePicker: some View {
        Section {
            Picker("Mode", selection: $triggerModeRaw) {
                ForEach(TriggerMode.allCases, id: \.rawValue) { m in
                    Label(m.rawValue, systemImage: m.icon).tag(m.rawValue)
                }
            }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    // MARK: - Contact

    private var contactSection: some View {
        Section {
            NavigationLink {
                ContactPickerView(selectedID: $selectedContactID)
                    .environmentObject(contactStore)
            } label: {
                HStack {
                    Text("Contact")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(selectedContact.name)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Who")
        }
    }

    // MARK: - Settings (mode-specific)

    @ViewBuilder
    private var settingsSection: some View {
        switch mode {
        case .call:
            delaySection(label: "Delay before call")

        case .message:
            Section {
                NavigationLink {
                    TemplatePickerView(selectedID: $selectedTemplateID)
                        .environmentObject(messageTemplateStore)
                } label: {
                    HStack {
                        Text("Message")
                        Spacer()
                        Text(selectedTemplate.text)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200, alignment: .trailing)
                    }
                }
            } header: {
                Text("What to Send")
            }
            delaySection(label: "Delay before notification")

        case .combo:
            Section {
                Stepper(
                    "Messages: \(comboMessageCount)",
                    value: $comboMessageCount,
                    in: 1...min(8, messageTemplateStore.templates.count)
                )

                sliderRow(
                    label: "Delay before first message",
                    value: $comboFirstMessageDelay,
                    range: 3...30
                )

                sliderRow(
                    label: "Interval between messages",
                    value: $comboMessageInterval,
                    range: 5...30
                )

                sliderRow(
                    label: "Delay before call",
                    value: $comboDelayBeforeCall,
                    range: 5...30
                )
            } header: {
                Text("Combo Settings")
            } footer: {
                Text("Sends the first \(comboMessageCount) messages from your Messages list in order, then calls. Reorder them in Manage > Messages to control the escalation.")
            }
        }
    }

    private func delaySection(label: String) -> some View {
        Section {
            sliderRow(label: label, value: $triggerDelay, range: 3...30)
        } header: {
            Text("Timing")
        }
    }

    private func sliderRow(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value.wrappedValue))s")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: 1).tint(.blue)
        }
    }

    // MARK: - Trigger Section

    @ViewBuilder
    private var triggerSection: some View {
        Section {
            switch mode {

            // ── Call ──────────────────────────────────────────────────────
            case .call:
                if let remaining = countdownRemaining {
                    countdownRow(remaining: remaining, color: .green) {
                        cancelPending()
                    }
                } else {
                    triggerButton(title: "Trigger Fake Call", icon: "phone.fill", color: .green) {
                        callManager.triggerFakeCall(from: selectedContact, delay: triggerDelay)
                        startCountdown(seconds: Int(triggerDelay))
                    }
                }

            // ── Message ───────────────────────────────────────────────────
            case .message:
                if notificationManager.isPermissionGranted {
                    if let remaining = countdownRemaining {
                        countdownRow(remaining: remaining, color: .blue) {
                            cancelPending()
                        }
                    } else {
                        triggerButton(title: "Send Notification", icon: "bell.badge.fill", color: .blue) {
                            let id = notificationManager.scheduleNotification(
                                contactName: selectedContact.name,
                                messageText: selectedTemplate.text,
                                delay: triggerDelay
                            )
                            pendingNotifID = id
                            startCountdown(seconds: Int(triggerDelay))
                        }
                    }
                } else {
                    triggerButton(title: "Allow Notifications", icon: "bell.slash.fill", color: .orange) {
                        Task { await notificationManager.requestPermission() }
                    }
                }

            // ── Combo ─────────────────────────────────────────────────────
            case .combo:
                if combo.isRunning {
                    Button(role: .destructive) {
                        combo.cancel()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Cancel Combo", systemImage: "xmark.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                } else {
                    triggerButton(title: "Trigger Combo", icon: "bolt.fill", color: .purple) {
                        combo.trigger(
                            contact: selectedContact,
                            templates: messageTemplateStore.templates,
                            messageCount: comboMessageCount,
                            firstMessageDelay: comboFirstMessageDelay,
                            messageInterval: comboMessageInterval,
                            delayBeforeCall: comboDelayBeforeCall
                        )
                    }
                }
            }

        } footer: {
            switch mode {
            case .call:
                if let remaining = countdownRemaining {
                    Text("Calling in \(remaining)s… tap Cancel to abort.")
                } else {
                    Text("Fake call from \(selectedContact.name) rings in \(Int(triggerDelay))s.")
                }
            case .message:
                if let remaining = countdownRemaining {
                    Text("Notification in \(remaining)s… tap Cancel to abort.")
                } else {
                    Text("Notification from \(selectedContact.name) fires in \(Int(triggerDelay))s.")
                }
            case .combo:
                if combo.isRunning {
                    Text("Combo running — messages sending, call incoming soon.")
                } else {
                    let totalTime = Int(comboFirstMessageDelay + Double(comboMessageCount - 1) * comboMessageInterval + comboDelayBeforeCall)
                    Text("\(comboMessageCount) messages from \(selectedContact.name), then a call ~\(totalTime)s total.")
                }
            }
        }
    }

    // MARK: - Trigger helpers

    private func triggerButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Spacer()
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
            }
        }
    }

    private func countdownRow(remaining: Int, color: Color, onCancel: @escaping () -> Void) -> some View {
        HStack {
            // Countdown pill
            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                Text("Triggering in \(remaining)s")
                    .monospacedDigit()
            }
            .font(.headline)
            .foregroundStyle(color)

            Spacer()

            // Cancel button
            Button(role: .destructive, action: onCancel) {
                Label("Cancel", systemImage: "xmark.circle.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderless)
        }
        .animation(.default, value: remaining)
    }

    // MARK: - Countdown logic

    private func startCountdown(seconds: Int) {
        countdownRemaining = seconds
        countdownTask = Task {
            for tick in stride(from: seconds, through: 0, by: -1) {
                guard !Task.isCancelled else { break }
                await MainActor.run { countdownRemaining = tick }
                if tick > 0 {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                }
            }
            if !Task.isCancelled {
                await MainActor.run { clearCountdown() }
            }
        }
    }

    private func cancelPending() {
        countdownTask?.cancel()
        clearCountdown()
        if let id = pendingNotifID {
            notificationManager.cancelNotification(id: id)
            pendingNotifID = nil
        }
        callManager.cancelPendingCall()
    }

    private func clearCountdown() {
        countdownTask?.cancel()
        countdownTask      = nil
        countdownRemaining = nil
    }

    // MARK: - Manage

    private var manageSection: some View {
        Section("Manage") {
            NavigationLink("Contacts") {
                ContactsEditView().environmentObject(contactStore)
            }
            NavigationLink("Messages") {
                MessagesEditView().environmentObject(messageTemplateStore)
            }
        }
    }

    // MARK: - Setup

    private var setupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Open **Settings** on your iPhone")
                step(2, "Tap **Action Button**")
                step(3, "Swipe to **Shortcut** → Choose a Shortcut")
                step(4, "Search **\"Fake Call\"**, **\"Fake Message\"**, or **\"Combo Escape\"**")
                step(5, "Select and you're done")
            }
            .padding(.vertical, 4)
        } header: {
            Text("Action Button Setup")
        } footer: {
            Text("Requires iPhone 15 Pro or later.")
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text).font(.subheadline)
        }
    }
}

// MARK: - Contact Picker

struct ContactPickerView: View {
    @EnvironmentObject var store: ContactStore
    @Binding var selectedID: String

    var body: some View {
        List {
            ForEach(store.contacts) { contact in
                Button {
                    selectedID = contact.id.uuidString
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).foregroundStyle(.primary)
                            Text(contact.phoneNumber).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if contact.id.uuidString == selectedID {
                            Image(systemName: "checkmark").foregroundStyle(.blue).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Contact")
    }
}

// MARK: - Template Picker

struct TemplatePickerView: View {
    @EnvironmentObject var store: MessageTemplateStore
    @Binding var selectedID: String

    var body: some View {
        List {
            ForEach(store.templates) { t in
                Button {
                    selectedID = t.id.uuidString
                } label: {
                    HStack {
                        Text(t.text).foregroundStyle(.primary)
                        Spacer()
                        if t.id.uuidString == selectedID {
                            Image(systemName: "checkmark").foregroundStyle(.blue).fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .navigationTitle("Choose Message")
    }
}

// MARK: - Contacts Edit View

struct ContactsEditView: View {
    @EnvironmentObject var store: ContactStore
    @State private var editingContact: Contact?  = nil
    @State private var showAddSheet              = false
    @State private var showImportPicker          = false
    @State private var importedCNContacts: [CNContact] = []

    var body: some View {
        List {
            ForEach(store.contacts) { contact in
                Button {
                    editingContact = contact
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name).foregroundStyle(.primary).font(.body)
                            Text(contact.phoneNumber).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
            .onDelete(perform: store.delete)
            .onMove(perform: store.move)
        }
        .navigationTitle("Contacts")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Label("Add Manually", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
        }
        .sheet(item: $editingContact) { contact in
            ContactEditSheet(contact: contact) { updated in store.update(updated) }
        }
        .sheet(isPresented: $showAddSheet) {
            ContactEditSheet(contact: nil) { newContact in store.add(newContact) }
        }
        .sheet(isPresented: $showImportPicker) {
            DeviceContactPicker(onSelect: { cnContacts in
                for cn in cnContacts {
                    let name  = [cn.givenName, cn.familyName]
                        .filter { !$0.isEmpty }.joined(separator: " ")
                    let phone = cn.phoneNumbers.first.map {
                        $0.value.stringValue
                    } ?? ""
                    guard !name.isEmpty else { continue }
                    // Skip duplicates
                    if store.contacts.contains(where: { $0.name == name }) { continue }
                    store.add(Contact(name: name, phoneNumber: phone))
                }
            })
        }
    }
}

// MARK: - Device Contact Picker (CNContactPickerViewController wrapper)

struct DeviceContactPicker: UIViewControllerRepresentable {
    let onSelect: ([CNContact]) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        // Only show contacts that have a phone number
        picker.predicateForEnablingContact = NSPredicate(
            format: "phoneNumbers.@count > 0"
        )
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: DeviceContactPicker
        init(_ parent: DeviceContactPicker) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contacts: [CNContact]) {
            parent.onSelect(contacts)
        }
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelect([contact])
        }
    }
}

struct ContactEditSheet: View {
    let contact: Contact?
    let onSave: (Contact) -> Void

    @State private var name: String
    @State private var phoneNumber: String
    @Environment(\.dismiss) private var dismiss

    init(contact: Contact?, onSave: @escaping (Contact) -> Void) {
        self.contact = contact
        self.onSave  = onSave
        _name        = State(initialValue: contact?.name ?? "")
        _phoneNumber = State(initialValue: contact?.phoneNumber ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Mom", text: $name)
                }
                Section("Phone Number") {
                    TextField("e.g. +1 (555) 123-4567", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
            }
            .navigationTitle(contact == nil ? "New Contact" : "Edit Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let saved = Contact(
                            id: contact?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespaces),
                            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespaces)
                        )
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Messages Edit View

struct MessagesEditView: View {
    @EnvironmentObject var store: MessageTemplateStore
    @State private var editingTemplate: MessageTemplate? = nil
    @State private var showAddSheet = false

    var body: some View {
        List {
            ForEach(store.templates) { template in
                Button {
                    editingTemplate = template
                } label: {
                    HStack {
                        Text(template.text)
                            .foregroundStyle(.primary)
                            .font(.body)
                            .multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "pencil").foregroundStyle(.secondary).font(.caption)
                    }
                }
            }
            .onDelete(perform: store.delete)
            .onMove(perform: store.move)
        }
        .navigationTitle("Messages")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: { Image(systemName: "plus") }
            }
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
        }
        .sheet(item: $editingTemplate) { template in
            MessageEditSheet(template: template) { updated in
                store.update(updated)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            MessageEditSheet(template: nil) { newTemplate in
                store.add(newTemplate)
            }
        }
        .navigationFooter("In Combo mode, messages are sent in this order. Drag to reorder.")
    }
}

struct MessageEditSheet: View {
    let template: MessageTemplate?
    let onSave: (MessageTemplate) -> Void

    @State private var text: String
    @Environment(\.dismiss) private var dismiss

    init(template: MessageTemplate?, onSave: @escaping (MessageTemplate) -> Void) {
        self.template = template
        self.onSave   = onSave
        _text = State(initialValue: template?.text ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message Text") {
                    TextEditor(text: $text)
                        .frame(minHeight: 80)
                }
                Section {
                    Text("Keep it natural and urgent. No emojis.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(template == nil ? "New Message" : "Edit Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let saved = MessageTemplate(
                            id: template?.id ?? UUID(),
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - View helper

private extension View {
    func navigationFooter(_ text: String) -> some View {
        self.safeAreaInset(edge: .bottom) {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
