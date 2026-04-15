import Foundation

// MARK: - Model

struct MessageTemplate: Identifiable, Codable, Equatable {
    var id: UUID
    var text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }

    static let defaults: [MessageTemplate] = [
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000001")!, text: "Hey, where are you?"),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000002")!, text: "Please call me back. It is important."),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000003")!, text: "I really need to talk to you right now."),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000004")!, text: "This is serious. Call me immediately."),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000005")!, text: "There has been an accident. Where are you?"),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000006")!, text: "We are at the hospital. Come as soon as you can."),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000007")!, text: "Something happened at home. Call me."),
        MessageTemplate(id: UUID(uuidString: "AA000001-0000-0000-0000-000000000008")!, text: "Why are you not picking up. I need you."),
    ]
}

// MARK: - Store

final class MessageTemplateStore: ObservableObject {
    static let shared = MessageTemplateStore()

    @Published var templates: [MessageTemplate] = []

    private let key = "message_templates_v2"

    init() {
        load()
        if templates.isEmpty {
            templates = MessageTemplate.defaults
            save()
        }
    }

    func add(_ template: MessageTemplate) {
        templates.append(template)
        save()
    }

    func update(_ template: MessageTemplate) {
        guard let idx = templates.firstIndex(where: { $0.id == template.id }) else { return }
        templates[idx] = template
        save()
    }

    func delete(at offsets: IndexSet) {
        templates.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        templates.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MessageTemplate].self, from: data) else { return }
        templates = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(templates) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
