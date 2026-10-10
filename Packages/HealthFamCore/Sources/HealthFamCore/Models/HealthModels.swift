import Foundation

/// Ein einzelner Herzfrequenz-Messwert.
public struct HeartRateSample: Codable, Hashable, Sendable {
    public var date: Date
    public var bpm: Double

    public init(date: Date, bpm: Double) {
        self.date = date
        self.bpm = bpm
    }
}

/// Ein zeitlich begrenzter Messwert (z. B. HRV oder Atemfrequenz).
public struct TimedValue: Codable, Hashable, Sendable {
    public var date: Date
    public var value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct WorkoutSummary: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var activityName: String
    public var symbolName: String
    public var start: Date
    public var end: Date
    public var activeEnergy: Double?
    public var distanceMeters: Double?
    public var averageHeartRate: Double?
    public var maxHeartRate: Double?

    public init(
        id: UUID = UUID(),
        activityName: String,
        symbolName: String,
        start: Date,
        end: Date,
        activeEnergy: Double? = nil,
        distanceMeters: Double? = nil,
        averageHeartRate: Double? = nil,
        maxHeartRate: Double? = nil
    ) {
        self.id = id
        self.activityName = activityName
        self.symbolName = symbolName
        self.start = start
        self.end = end
        self.activeEnergy = activeEnergy
        self.distanceMeters = distanceMeters
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
    }

    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func contains(_ date: Date) -> Bool { date >= start && date <= end }
}

public struct NutritionSummary: Codable, Hashable, Sendable {
    public var calories: Double
    public var protein: Double
    public var carbohydrates: Double
    public var fat: Double
    public var water: Double

    public init(calories: Double = 0, protein: Double = 0, carbohydrates: Double = 0, fat: Double = 0, water: Double = 0) {
        self.calories = calories
        self.protein = protein
        self.carbohydrates = carbohydrates
        self.fat = fat
        self.water = water
    }

    public static let empty = NutritionSummary()
}

/// Rohdaten eines Kalendertages, wie sie aus Apple Health gelesen werden.
public struct DailyMetrics: Codable, Hashable, Sendable, Identifiable {
    /// Tagesbeginn (00:00 lokale Zeit).
    public var day: Date
    /// Nächtliche Herzfrequenzvariabilität (SDNN, Millisekunden).
    public var hrv: Double?
    /// Ruhepuls (Schläge pro Minute).
    public var restingHeartRate: Double?
    /// Nächtliche Atemfrequenz (Atemzüge pro Minute).
    public var respiratoryRate: Double?
    /// Blutsauerstoff (0...1).
    public var oxygenSaturation: Double?
    /// Handgelenkstemperatur im Schlaf (°C, absolut).
    public var wristTemperature: Double?
    public var vo2Max: Double?
    public var steps: Double
    public var activeEnergy: Double
    public var basalEnergy: Double
    /// Hauptschlaf, der an diesem Morgen endete.
    public var sleep: SleepSession?
    public var heartRateSamples: [HeartRateSample]
    public var workouts: [WorkoutSummary]
    public var nutrition: NutritionSummary

    public var id: Date { day }

    public init(
        day: Date,
        hrv: Double? = nil,
        restingHeartRate: Double? = nil,
        respiratoryRate: Double? = nil,
        oxygenSaturation: Double? = nil,
        wristTemperature: Double? = nil,
        vo2Max: Double? = nil,
        steps: Double = 0,
        activeEnergy: Double = 0,
        basalEnergy: Double = 0,
        sleep: SleepSession? = nil,
        heartRateSamples: [HeartRateSample] = [],
        workouts: [WorkoutSummary] = [],
        nutrition: NutritionSummary = .empty
    ) {
        self.day = day
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
        self.wristTemperature = wristTemperature
        self.vo2Max = vo2Max
        self.steps = steps
        self.activeEnergy = activeEnergy
        self.basalEnergy = basalEnergy
        self.sleep = sleep
        self.heartRateSamples = heartRateSamples
        self.workouts = workouts
        self.nutrition = nutrition
    }
}

public enum BiologicalSex: String, Codable, Sendable, CaseIterable {
    case female, male, other

    public var displayName: String {
        switch self {
        case .female: return "Weiblich"
        case .male: return "Männlich"
        case .other: return "Divers"
        }
    }
}

public struct UserProfile: Codable, Hashable, Sendable {
    public var name: String
    public var age: Int
    public var sex: BiologicalSex
    public var sleepGoalHours: Double
    /// Optional manuell gesetzter Maximalpuls.
    public var maxHeartRateOverride: Double?
    public var calorieGoal: Double
    public var proteinGoal: Double

    public init(
        name: String = "",
        age: Int = 30,
        sex: BiologicalSex = .other,
        sleepGoalHours: Double = 8,
        maxHeartRateOverride: Double? = nil,
        calorieGoal: Double = 2200,
        proteinGoal: Double = 120
    ) {
        self.name = name
        self.age = age
        self.sex = sex
        self.sleepGoalHours = sleepGoalHours
        self.maxHeartRateOverride = maxHeartRateOverride
        self.calorieGoal = calorieGoal
        self.proteinGoal = proteinGoal
    }

    /// Maximalpuls nach Tanaka (208 − 0,7 × Alter), sofern nicht manuell gesetzt.
    public var maxHeartRate: Double {
        maxHeartRateOverride ?? (208 - 0.7 * Double(age))
    }
}
