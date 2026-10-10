import Foundation

/// Ein Faktor, der einen Score positiv oder negativ beeinflusst.
public struct ScoreContributor: Codable, Hashable, Sendable, Identifiable {
    public var name: String
    public var value: String
    public var baseline: String?
    /// −1 (stark negativ) … +1 (stark positiv)
    public var impact: Double

    public var id: String { name }

    public init(name: String, value: String, baseline: String? = nil, impact: Double) {
        self.name = name
        self.value = value
        self.baseline = baseline
        self.impact = Stats.clamp(impact, -1, 1)
    }
}

public enum ScoreLevel: String, Codable, Sendable {
    case low, moderate, high

    public init(score: Int, lowBelow: Int = 34, highFrom: Int = 67) {
        if score < lowBelow {
            self = .low
        } else if score >= highFrom {
            self = .high
        } else {
            self = .moderate
        }
    }
}

public struct RecoveryResult: Codable, Hashable, Sendable {
    public var score: Int
    public var level: ScoreLevel
    public var contributors: [ScoreContributor]
    /// Wird angezeigt, solange noch zu wenig Historie für eine Baseline vorliegt.
    public var isCalibrating: Bool

    public var headline: String {
        switch level {
        case .high: return "Dein Körper ist bereit für Belastung."
        case .moderate: return "Moderat erholt – trainiere mit Augenmaß."
        case .low: return "Gönn dir heute Erholung."
        }
    }
}

public struct HeartRateZone: Codable, Hashable, Sendable, Identifiable {
    public var index: Int
    /// Untere Grenze in % der Herzfrequenzreserve.
    public var lowerBound: Double
    public var upperBound: Double
    public var duration: TimeInterval

    public var id: Int { index }

    public var name: String {
        switch index {
        case 1: return "Zone 1 · Locker"
        case 2: return "Zone 2 · Grundlage"
        case 3: return "Zone 3 · Tempo"
        case 4: return "Zone 4 · Schwelle"
        default: return "Zone 5 · Maximal"
        }
    }
}

public struct StrainResult: Codable, Hashable, Sendable {
    /// 0 … 100 %
    public var score: Int
    /// Trainingsimpuls nach Banister.
    public var trimp: Double
    public var zones: [HeartRateZone]
    public var activeEnergy: Double
    public var steps: Double

    public var level: ScoreLevel { ScoreLevel(score: score, lowBelow: 30, highFrom: 65) }
}

public struct StrainTarget: Codable, Hashable, Sendable {
    public var lower: Int
    public var upper: Int

    public var description: String {
        "\(lower)–\(upper) %"
    }
}

public struct SleepResult: Codable, Hashable, Sendable {
    public var score: Int
    public var asleep: TimeInterval
    public var need: TimeInterval
    public var efficiency: Double
    public var restorativeRatio: Double?
    public var contributors: [ScoreContributor]

    public var level: ScoreLevel { ScoreLevel(score: score, lowBelow: 50, highFrom: 80) }
}

public struct StressPoint: Codable, Hashable, Sendable, Identifiable {
    public var hour: Date
    /// 0 … 100
    public var level: Double
    public var isActivity: Bool

    public var id: Date { hour }
}

public struct StressResult: Codable, Hashable, Sendable {
    /// Durchschnittlicher Stress im Wachzustand, 0 … 100
    public var average: Int
    public var peak: Int
    public var timeline: [StressPoint]

    public var level: ScoreLevel { ScoreLevel(score: average, lowBelow: 30, highFrom: 60) }

    public var label: String {
        switch level {
        case .low: return "Entspannt"
        case .moderate: return "Mittel"
        case .high: return "Hoch"
        }
    }
}
