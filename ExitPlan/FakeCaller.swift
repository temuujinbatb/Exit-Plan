import Foundation

// MARK: - Model

struct Contact: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var phoneNumber: String

    init(id: UUID = UUID(), name: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
    }

    static let defaults: [Contact] = [
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000001")!, name: "Mom",    phoneNumber: "+1 (555) 867-5309"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000002")!, name: "Dad",    phoneNumber: "+1 (555) 234-5678"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000003")!, name: "Sis",    phoneNumber: "+1 (555) 345-6789"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000004")!, name: "Bro",    phoneNumber: "+1 (555) 456-7890"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000005")!, name: "Babe",   phoneNumber: "+1 (555) 890-1234"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000006")!, name: "Boss",   phoneNumber: "+1 (555) 567-8901"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000007")!, name: "Work",   phoneNumber: "+1 (555) 678-9012"),
        Contact(id: UUID(uuidString: "CC000001-0000-0000-0000-000000000008")!, name: "Doctor", phoneNumber: "+1 (555) 789-0123"),
    ]
}

// MARK: - Store

final class ContactStore: ObservableObject {
    static let shared = ContactStore()

    @Published var contacts: [Contact] = []

    private let key = "contacts_v2"

    init() {
        load()
        if contacts.isEmpty {
            contacts = Contact.defaults
            save()
        }
    }

    func add(_ contact: Contact) {
        contacts.append(contact)
        save()
    }

    func update(_ contact: Contact) {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        contacts[idx] = contact
        save()
    }

    func delete(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        contacts.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Contact].self, from: data) else { return }
        contacts = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
