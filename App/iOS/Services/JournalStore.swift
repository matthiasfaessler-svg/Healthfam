import Foundation
import HealthFamCore

/// Speichert Journal-Einträge lokal als JSON.
@MainActor
final class JournalStore: ObservableObject {
    @Published private(set) var entries: [JournalEntry] = []

    private let url: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("journal.json")

    init() {
        if let data = try? Data(contentsOf: url),
           let stored = try? JSONDecoder().decode([JournalEntry].self, from: data) {
            entries = stored
        }
    }

    func entry(for day: Date) -> JournalEntry {
        let start = Calendar.current.startOfDay(for: day)
        return entries.first { Calendar.current.isDate($0.day, inSameDayAs: start) } ?? JournalEntry(day: start)
    }

    func save(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
        persist()
    }

    func toggle(tag: String, on day: Date) {
        var entry = entry(for: day)
        if entry.tagIDs.contains(tag) {
            entry.tagIDs.remove(tag)
        } else {
            entry.tagIDs.insert(tag)
        }
        save(entry)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: url, options: [.atomic, .completeFileProtection])
        }
    }

    static func tag(_ id: String) -> JournalTag? {
        JournalTag.defaults.first { $0.id == id }
    }
}
