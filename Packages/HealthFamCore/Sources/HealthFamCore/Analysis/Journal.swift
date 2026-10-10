import Foundation

public struct JournalTag: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var symbolName: String
    public var category: Category

    public enum Category: String, Codable, Sendable, CaseIterable {
        case lifestyle, nutrition, recovery, health

        public var displayName: String {
            switch self {
            case .lifestyle: return "Lebensstil"
            case .nutrition: return "Ernährung"
            case .recovery: return "Erholung"
            case .health: return "Gesundheit"
            }
        }
    }

    public init(id: String, name: String, symbolName: String, category: Category) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.category = category
    }

    public static let defaults: [JournalTag] = [
        JournalTag(id: "alcohol", name: "Alkohol", symbolName: "wineglass", category: .nutrition),
        JournalTag(id: "late_caffeine", name: "Koffein nach 14 Uhr", symbolName: "cup.and.saucer", category: .nutrition),
        JournalTag(id: "late_meal", name: "Spätes Essen", symbolName: "fork.knife", category: .nutrition),
        JournalTag(id: "sugar", name: "Viel Zucker", symbolName: "birthday.cake", category: .nutrition),
        JournalTag(id: "hydrated", name: "Genug getrunken", symbolName: "drop", category: .nutrition),
        JournalTag(id: "screens", name: "Bildschirm vor dem Schlafen", symbolName: "iphone", category: .lifestyle),
        JournalTag(id: "work_stress", name: "Stress bei der Arbeit", symbolName: "briefcase", category: .lifestyle),
        JournalTag(id: "travel", name: "Reise", symbolName: "airplane", category: .lifestyle),
        JournalTag(id: "outdoors", name: "Zeit draußen", symbolName: "sun.max", category: .lifestyle),
        JournalTag(id: "reading", name: "Lesen vor dem Schlafen", symbolName: "book", category: .lifestyle),
        JournalTag(id: "meditation", name: "Meditation", symbolName: "brain.head.profile", category: .recovery),
        JournalTag(id: "stretching", name: "Dehnen / Mobility", symbolName: "figure.cooldown", category: .recovery),
        JournalTag(id: "sauna", name: "Sauna", symbolName: "flame", category: .recovery),
        JournalTag(id: "cold", name: "Kältebad", symbolName: "snowflake", category: .recovery),
        JournalTag(id: "magnesium", name: "Magnesium", symbolName: "pills", category: .health),
        JournalTag(id: "sick", name: "Krank", symbolName: "facemask", category: .health),
        JournalTag(id: "sore", name: "Muskelkater", symbolName: "bandage", category: .health)
    ]
}

public struct JournalEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var day: Date
    public var tagIDs: Set<String>
    /// 1 (schlecht) … 5 (super)
    public var mood: Int?
    public var note: String

    public init(id: UUID = UUID(), day: Date, tagIDs: Set<String> = [], mood: Int? = nil, note: String = "") {
        self.id = id
        self.day = day
        self.tagIDs = tagIDs
        self.mood = mood
        self.note = note
    }
}

public struct JournalImpact: Hashable, Sendable, Identifiable {
    public var tagID: String
    public var averageWith: Double
    public var averageWithout: Double
    public var occurrences: Int

    public var id: String { tagID }
    public var delta: Double { averageWith - averageWithout }
}

/// Wertet aus, wie sich Journal-Gewohnheiten auf die Erholung am Folgetag auswirken.
public enum JournalAnalyzer {
    public static func impacts(
        entries: [JournalEntry],
        recoveryByDay: [Date: Int],
        minimumOccurrences: Int = 3,
        calendar: Calendar = .current
    ) -> [JournalImpact] {
        var tagsByDay: [Date: Set<String>] = [:]
        for entry in entries {
            tagsByDay[calendar.startOfDay(for: entry.day), default: []].formUnion(entry.tagIDs)
        }

        // Paare aus (Tags am Tag D, Recovery am Tag D+1)
        let pairs: [(tags: Set<String>, recovery: Double)] = tagsByDay.compactMap { day, tags in
            guard let next = calendar.date(byAdding: .day, value: 1, to: day),
                  let recovery = recoveryByDay[calendar.startOfDay(for: next)] else { return nil }
            return (tags, Double(recovery))
        }

        let allTags = Set(pairs.flatMap(\.tags))
        return allTags.compactMap { tag -> JournalImpact? in
            let with = pairs.filter { $0.tags.contains(tag) }.map(\.recovery)
            let without = pairs.filter { !$0.tags.contains(tag) }.map(\.recovery)
            guard with.count >= minimumOccurrences, without.count >= minimumOccurrences,
                  let a = Stats.mean(with), let b = Stats.mean(without) else { return nil }
            return JournalImpact(tagID: tag, averageWith: a, averageWithout: b, occurrences: with.count)
        }
        .sorted { abs($0.delta) > abs($1.delta) }
    }
}
