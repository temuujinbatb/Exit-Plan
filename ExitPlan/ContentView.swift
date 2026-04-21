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

    @State private var showInCallView        = false
    @State private var showContactPicker     = false
    @State private var showTemplatePicker    = false
    @State private var showProfileSheet      = false
    @State private var countdownRemaining: Int?         = nil
    @State private var pendingNotifID: String?          = nil
    @State private var countdownTask: Task<Void, Never>? = nil

    @StateObject private var combo = ComboManager.shared

    @Environment(\.colorScheme) private var scheme

    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            EPScreen {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerRow
                        modeSegment
                        contactCard
                        settingsCard
                        triggerArea
                        manageRow
                        setupCard
                        Spacer(minLength: 80)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
            }
            .navigationBarHidden(true)
        }
        // In-call full-screen
        .fullScreenCover(isPresented: $showInCallView) {
            InCallView(onMinimize: { showInCallView = false })
                .environmentObject(callManager)
        }
        // Profile sheet
        .sheet(isPresented: $showProfileSheet) {
            NavigationStack {
                ProfileView()
                    .environmentObject(authManager)
                    .environmentObject(contactStore)
                    .environmentObject(messageTemplateStore)
            }
        }
        // Contact picker sheet
        .sheet(isPresented: $showContactPicker) {
            NavigationStack {
                ContactPickerView(selectedID: $selectedContactID)
                    .environmentObject(contactStore)
            }
        }
        // Template picker sheet
        .sheet(isPresented: $showTemplatePicker) {
            NavigationStack {
                TemplatePickerView(selectedID: $selectedTemplateID)
                    .environmentObject(messageTemplateStore)
            }
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
                clearCountdown()
                showInCallView = true
            }
        }
        .onChange(of: triggerModeRaw) { _, _ in
            clearCountdown()
        }
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("EXIT PLAN")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(t.inkFaint)
                Text("Ready when you are")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(t.ink)
            }
            Spacer()
            EPCircleButton(size: 42, accent: false, action: { showProfileSheet = true }) {
                Image(systemName: "person.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(t.inkSoft)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Mode Segment

    private var modeSegment: some View {
        EPSegmented(
            selection: $triggerModeRaw,
            options: TriggerMode.allCases.map { (value: $0.rawValue, label: $0.rawValue, icon: $0.icon) }
        )
        .animation(.spring(response: 0.3), value: triggerModeRaw)
    }

    // MARK: - Contact Card

    private var contactCard: some View {
        EPCard(padding: 16) {
            EPLabel(text: "Contact")
            Spacer().frame(height: 12)
            Button { showContactPicker = true } label: {
                HStack(spacing: 12) {
                    EPAvatar(name: selectedContact.name, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedContact.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(t.ink)
                        Text(selectedContact.phoneNumber)
                            .font(.system(size: 13))
                            .foregroundStyle(t.inkSoft)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(t.inkFaint)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Settings Card (mode-specific)

    @ViewBuilder
    private var settingsCard: some View {
        switch mode {
        case .call:
            delayCard(label: "Delay before call", value: $triggerDelay, range: 3...30)

        case .message:
            VStack(spacing: 14) {
                EPCard(padding: 16) {
                    EPLabel(text: "Message")
                    Spacer().frame(height: 12)
                    Button { showTemplatePicker = true } label: {
                        HStack {
                            Text(selectedTemplate.text)
                                .font(.system(size: 15))
                                .foregroundStyle(t.ink)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(t.inkFaint)
                        }
                    }
                    .buttonStyle(.plain)
                }
                delayCard(label: "Delay before notification", value: $triggerDelay, range: 3...30)
            }

        case .combo:
            EPCard(padding: 16) {
                EPLabel(text: "Combo Settings")
                Spacer().frame(height: 14)

                // Message count stepper
                HStack {
                    Text("Messages")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(t.ink)
                    Spacer()
                    HStack(spacing: 0) {
                        Button {
                            if comboMessageCount > 1 { comboMessageCount -= 1 }
                        } label: {
                            Image(systemName: "minus")
                                .frame(width: 32, height: 32)
                                .foregroundStyle(t.inkSoft)
                        }
                        Text("\(comboMessageCount)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.epAccentDeep)
                            .frame(width: 32)
                        Button {
                            let max = min(8, messageTemplateStore.templates.count)
                            if comboMessageCount < max { comboMessageCount += 1 }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 32, height: 32)
                                .foregroundStyle(t.inkSoft)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(t.bgDeep)
                            .shadow(color: t.shadowDark,  radius: 3, x: 2, y: 2)
                            .shadow(color: t.shadowLight, radius: 3, x: -2, y: -2)
                    )
                }

                Divider().padding(.vertical, 8).opacity(0.4)

                sliderBlock(label: "Delay before 1st message", value: $comboFirstMessageDelay, range: 3...30)
                Spacer().frame(height: 14)
                sliderBlock(label: "Interval between messages", value: $comboMessageInterval, range: 5...30)
                Spacer().frame(height: 14)
                sliderBlock(label: "Delay before call", value: $comboDelayBeforeCall, range: 5...30)

                Divider().padding(.vertical, 8).opacity(0.4)

                Text("Messages are sent in order from your Messages list. Drag to reorder.")
                    .font(.system(size: 11))
                    .foregroundStyle(t.inkFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func delayCard(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        EPCard(padding: 16) {
            EPLabel(text: "Timing")
            Spacer().frame(height: 14)
            sliderBlock(label: label, value: value, range: range)
        }
    }

    private func sliderBlock(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(label)
                    .font(.system(size: 14))
                    .foregroundStyle(t.inkSoft)
                Spacer()
                Text("\(Int(value.wrappedValue))s")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(t.ink)
                    .monospacedDigit()
            }
            EPSlider(value: value, range: range, step: 1)
        }
    }

    // MARK: - Trigger Area

    @ViewBuilder
    private var triggerArea: some View {
        switch mode {
        case .call:
            if let remaining = countdownRemaining {
                countdownView(remaining: remaining, total: Int(triggerDelay), label: "Calling", color: .epAccent) {
                    cancelPending()
                }
            } else {
                triggerButton(label: "CALL", icon: "phone.fill", accent: true) {
                    callManager.triggerFakeCall(from: selectedContact, delay: triggerDelay)
                    startCountdown(seconds: Int(triggerDelay))
                }
            }

        case .message:
            if notificationManager.isPermissionGranted {
                if let remaining = countdownRemaining {
                    countdownView(remaining: remaining, total: Int(triggerDelay), label: "Sending", color: .epAccent) {
                        cancelPending()
                    }
                } else {
                    triggerButton(label: "SEND", icon: "bell.fill", accent: true) {
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
                triggerButton(label: "ALLOW", icon: "bell.slash.fill", accent: false) {
                    Task { await notificationManager.requestPermission() }
                }
            }

        case .combo:
            if combo.isRunning {
                EPCard(padding: 20) {
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.epAccent)
                                .frame(width: 8, height: 8)
                                .scaleEffect(combo.isRunning ? 1.4 : 1.0)
                                .animation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: combo.isRunning)
                            Text("Combo Running")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(t.ink)
                            Spacer()
                        }
                        Text("Messages sending, call incoming soon…")
                            .font(.system(size: 13))
                            .foregroundStyle(t.inkSoft)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            combo.cancel()
                        } label: {
                            HStack {
                                Image(systemName: "xmark")
                                Text("Cancel Combo")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.8))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                triggerButton(label: "COMBO", icon: "bolt.fill", accent: true) {
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
    }

    // MARK: - Trigger Button (large circular)

    private func triggerButton(label: String, icon: String, accent: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 14) {
            Button(action: action) {
                ZStack {
                    // Outer neumorphic ring
                    Circle()
                        .fill(t.bg)
                        .shadow(color: t.shadowDark,  radius: 14, x: 10, y: 10)
                        .shadow(color: t.shadowLight, radius: 14, x: -10, y: -10)
                        .frame(width: 170, height: 170)
                    // Inner gradient fill
                    Circle()
                        .fill(
                            accent
                            ? AnyShapeStyle(LinearGradient(
                                colors: [.epAccent, .epAccentDeep],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(t.bgDeep)
                        )
                        .frame(width: 138, height: 138)
                    // Icon + label
                    VStack(spacing: 8) {
                        Image(systemName: icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(accent ? .white : t.inkSoft)
                        Text(label)
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(accent ? .white.opacity(0.85) : t.inkFaint)
                    }
                }
            }
            .buttonStyle(.plain)

            statusFootnote
        }
    }

    // MARK: - Countdown Arc View

    private func countdownView(remaining: Int, total: Int, label: String, color: Color, onCancel: @escaping () -> Void) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Neumorphic outer ring
                Circle()
                    .fill(t.bg)
                    .shadow(color: t.shadowDark,  radius: 14, x: 10, y: 10)
                    .shadow(color: t.shadowLight, radius: 14, x: -10, y: -10)
                    .frame(width: 170, height: 170)

                // Background track
                Circle()
                    .stroke(t.bgDeep, lineWidth: 10)
                    .frame(width: 130, height: 130)

                // Progress arc
                Circle()
                    .trim(from: 0, to: total > 0 ? CGFloat(remaining) / CGFloat(total) : 0)
                    .stroke(
                        LinearGradient(colors: [.epAccent, .epAccentDeep], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: remaining)

                // Center content
                VStack(spacing: 4) {
                    Text("\(remaining)")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(t.ink)
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.default, value: remaining)
                    Text(label + "…")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.5)
                        .foregroundStyle(t.inkFaint)
                }
            }

            // Cancel capsule
            Button(action: onCancel) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Cancel")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(t.inkSoft)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(t.bg)
                        .shadow(color: t.shadowDark,  radius: 6, x: 4, y: 4)
                        .shadow(color: t.shadowLight, radius: 6, x: -4, y: -4)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Status Footnote

    @ViewBuilder
    private var statusFootnote: some View {
        switch mode {
        case .call:
            footnote("Rings from \(selectedContact.name) in \(Int(triggerDelay))s")
        case .message:
            if notificationManager.isPermissionGranted {
                footnote("Notification from \(selectedContact.name) in \(Int(triggerDelay))s")
            } else {
                footnote("Tap to enable notifications")
            }
        case .combo:
            let total = Int(comboFirstMessageDelay + Double(comboMessageCount - 1) * comboMessageInterval + comboDelayBeforeCall)
            footnote("\(comboMessageCount) messages then a call — ~\(total)s total")
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(t.inkFaint)
            .multilineTextAlignment(.center)
    }

    // MARK: - Manage Row

    private var manageRow: some View {
        EPCard(padding: 16) {
            EPLabel(text: "Manage")
            Spacer().frame(height: 12)
            HStack(spacing: 12) {
                NavigationLink {
                    ContactsEditView().environmentObject(contactStore)
                } label: {
                    manageChip(icon: "person.2.fill", label: "Contacts")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    MessagesEditView().environmentObject(messageTemplateStore)
                } label: {
                    manageChip(icon: "text.bubble.fill", label: "Messages")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func manageChip(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.epAccentDeep)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(t.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11))
                .foregroundStyle(t.inkFaint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(t.bgDeep)
                .shadow(color: t.shadowDark,  radius: 4, x: 3, y: 3)
                .shadow(color: t.shadowLight, radius: 4, x: -3, y: -3)
        )
    }

    // MARK: - Setup Card

    private var setupCard: some View {
        EPCard(padding: 16) {
            EPLabel(text: "Action Button Setup", trailing: "iPhone 15 Pro+")
            Spacer().frame(height: 12)
            VStack(alignment: .leading, spacing: 10) {
                setupStep(1, "Open Settings on your iPhone")
                setupStep(2, "Tap Action Button")
                setupStep(3, "Swipe to Shortcut → Choose a Shortcut")
                setupStep(4, "Search \"Fake Call\", \"Fake Message\", or \"Combo Escape\"")
                setupStep(5, "Select and you're done")
            }
        }
    }

    private func setupStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.epAccentDeep))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(t.inkSoft)
        }
    }

    // MARK: - Countdown Logic

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
}

// MARK: - Contact Picker

struct ContactPickerView: View {
    @EnvironmentObject var store: ContactStore
    @Binding var selectedID: String
    @Environment(\.colorScheme) private var scheme
    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        EPScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(store.contacts) { contact in
                        Button {
                            selectedID = contact.id.uuidString
                        } label: {
                            EPCard(padding: 14) {
                                HStack(spacing: 12) {
                                    EPAvatar(name: contact.name, size: 38)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(contact.name)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundStyle(t.ink)
                                        Text(contact.phoneNumber)
                                            .font(.system(size: 12))
                                            .foregroundStyle(t.inkSoft)
                                    }
                                    Spacer()
                                    if contact.id.uuidString == selectedID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.epAccent)
                                            .font(.system(size: 18))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Choose Contact")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Template Picker

struct TemplatePickerView: View {
    @EnvironmentObject var store: MessageTemplateStore
    @Binding var selectedID: String
    @Environment(\.colorScheme) private var scheme
    private var t: EPTheme { EPTheme(isDark: scheme == .dark) }

    var body: some View {
        EPScreen {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(store.templates) { template in
                        Button {
                            selectedID = template.id.uuidString
                        } label: {
                            EPCard(padding: 14) {
                                HStack(alignment: .top, spacing: 12) {
                                    Text(template.text)
                                        .font(.system(size: 15))
                                        .foregroundStyle(t.ink)
                                        .multilineTextAlignment(.leading)
                                    Spacer()
                                    if template.id.uuidString == selectedID {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.epAccent)
                                            .font(.system(size: 18))
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .navigationTitle("Choose Message")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Contacts Edit View

struct ContactsEditView: View {
    @EnvironmentObject var store: ContactStore
    @State private var editingContact: Contact?  = nil
    @State private var showAddSheet              = false
    @State private var showImportPicker          = false

    var body: some View {
        List {
            ForEach(store.contacts) { contact in
                Button {
                    editingContact = contact
                } label: {
                    HStack(spacing: 12) {
                        EPAvatar(name: contact.name, size: 36)
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
                    let phone = cn.phoneNumbers.first.map { $0.value.stringValue } ?? ""
                    guard !name.isEmpty else { continue }
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
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0")
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
            MessageEditSheet(template: template) { updated in store.update(updated) }
        }
        .sheet(isPresented: $showAddSheet) {
            MessageEditSheet(template: nil) { newTemplate in store.add(newTemplate) }
        }
        .safeAreaInset(edge: .bottom) {
            Text("In Combo mode, messages are sent in this order. Drag to reorder.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
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
