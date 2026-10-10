import HealthKit

extension HKWorkoutActivityType {
    /// Trainingsarten, die in der Watch-App direkt gestartet werden können.
    static let quickStart: [HKWorkoutActivityType] = [
        .running, .cycling, .traditionalStrengthTraining, .highIntensityIntervalTraining,
        .walking, .swimming, .yoga, .rowing, .hiking, .functionalStrengthTraining
    ]

    var displayName: String {
        switch self {
        case .running: return "Laufen"
        case .cycling: return "Radfahren"
        case .walking: return "Gehen"
        case .hiking: return "Wandern"
        case .swimming: return "Schwimmen"
        case .rowing: return "Rudern"
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .traditionalStrengthTraining: return "Krafttraining"
        case .functionalStrengthTraining: return "Funktionelles Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .crossTraining: return "Cross-Training"
        case .elliptical: return "Crosstrainer"
        case .stairClimbing: return "Treppensteigen"
        case .soccer: return "Fußball"
        case .tennis: return "Tennis"
        case .basketball: return "Basketball"
        case .dance: return "Tanzen"
        case .coreTraining: return "Core-Training"
        case .mindAndBody: return "Achtsamkeit"
        case .downhillSkiing: return "Skifahren"
        case .snowboarding: return "Snowboarden"
        case .climbing: return "Klettern"
        case .boxing: return "Boxen"
        default: return "Training"
        }
    }

    var symbolName: String {
        switch self {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .swimming: return "figure.pool.swim"
        case .rowing: return "figure.rower"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .traditionalStrengthTraining: return "dumbbell"
        case .functionalStrengthTraining: return "figure.strengthtraining.functional"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .crossTraining: return "figure.cross.training"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stairs"
        case .soccer: return "figure.soccer"
        case .tennis: return "figure.tennis"
        case .basketball: return "figure.basketball"
        case .dance: return "figure.dance"
        case .coreTraining: return "figure.core.training"
        case .mindAndBody: return "figure.mind.and.body"
        case .downhillSkiing: return "figure.skiing.downhill"
        case .snowboarding: return "figure.snowboarding"
        case .climbing: return "figure.climbing"
        case .boxing: return "figure.boxing"
        default: return "figure.mixed.cardio"
        }
    }

    var isOutdoorCapable: Bool {
        [.running, .cycling, .walking, .hiking].contains(self)
    }
}
