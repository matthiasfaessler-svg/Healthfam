import Foundation

/// Berechnet die Tagesbelastung (Strain, 0–100 %) über den Trainingsimpuls
/// (TRIMP nach Banister) aus allen Herzfrequenzmessungen des Tages.
public enum StrainCalculator {
    /// Herzfrequenzreserve, ab der Belastung gezählt wird.
    public static let countingThreshold = 0.3
    /// Längster Abstand zwischen zwei Messungen, der noch als durchgehend gilt.
    public static let maxSampleGap: TimeInterval = 15 * 60
    /// Skalierung: TRIMP von 180 entspricht ~63 % Strain.
    public static let scale = 180.0

    public static func calculate(
        samples: [HeartRateSample],
        restingHeartRate: Double,
        maxHeartRate: Double,
        sex: BiologicalSex,
        steps: Double = 0,
        activeEnergy: Double = 0
    ) -> StrainResult {
        let trimpAndZones = trimp(samples: samples, restingHeartRate: restingHeartRate, maxHeartRate: maxHeartRate, sex: sex)
        // Kleiner Beitrag aus Alltagsbewegung, die kaum den Puls hebt.
        let movement = steps / 2000
        let total = trimpAndZones.trimp + movement
        return StrainResult(
            score: score(forTRIMP: total),
            trimp: total,
            zones: trimpAndZones.zones,
            activeEnergy: activeEnergy,
            steps: steps
        )
    }

    public static func score(forTRIMP trimp: Double) -> Int {
        Int(Stats.clamp(100 * (1 - exp(-max(0, trimp) / scale)), 0, 100).rounded())
    }

    public static func trimp(
        samples: [HeartRateSample],
        restingHeartRate: Double,
        maxHeartRate: Double,
        sex: BiologicalSex
    ) -> (trimp: Double, zones: [HeartRateZone]) {
        let bounds: [(Double, Double)] = [(0.5, 0.6), (0.6, 0.7), (0.7, 0.8), (0.8, 0.9), (0.9, 1.01)]
        var zoneDurations = Array(repeating: 0.0, count: bounds.count)
        let reserve = max(maxHeartRate - restingHeartRate, 1)
        // Geschlechtsspezifische Gewichtung nach Banister.
        let (a, b): (Double, Double) = sex == .female ? (0.86, 1.67) : (0.64, 1.92)

        let sorted = samples.sorted { $0.date < $1.date }
        var total = 0.0
        for (index, sample) in sorted.enumerated() {
            let interval: TimeInterval
            if index + 1 < sorted.count {
                let gap = sorted[index + 1].date.timeIntervalSince(sample.date)
                interval = gap > maxSampleGap ? 60 : gap
            } else {
                interval = 60
            }
            let hrr = Stats.clamp((sample.bpm - restingHeartRate) / reserve, 0, 1)
            if hrr >= countingThreshold {
                total += (interval / 60) * hrr * a * exp(b * hrr)
            }
            if let zone = bounds.firstIndex(where: { hrr >= $0.0 && hrr < $0.1 }) {
                zoneDurations[zone] += interval
            }
        }

        let zones = bounds.enumerated().map { index, bound in
            HeartRateZone(index: index + 1, lowerBound: bound.0, upperBound: min(bound.1, 1), duration: zoneDurations[index])
        }
        return (total, zones)
    }
}
