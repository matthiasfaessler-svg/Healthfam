import Foundation

/// Schätzt den Stresspegel pro Stunde aus der Herzfrequenz im Ruhezustand
/// (außerhalb von Training und Schlaf) relativ zum Ruhepuls.
public enum StressCalculator {
    public static func calculate(
        samples: [HeartRateSample],
        restingHeartRate: Double,
        maxHeartRate: Double,
        workouts: [WorkoutSummary],
        sleep: SleepSession?,
        hrvZScore: Double? = nil,
        calendar: Calendar = .current
    ) -> StressResult? {
        let reserve = max(maxHeartRate - restingHeartRate, 1)
        let awake = samples.filter { sample in
            if let sleep, let start = sleep.start, let end = sleep.end, sample.date >= start && sample.date <= end {
                return false
            }
            return true
        }
        guard !awake.isEmpty else { return nil }

        let byHour = Dictionary(grouping: awake) { sample in
            calendar.dateInterval(of: .hour, for: sample.date)?.start ?? sample.date
        }

        // Eine niedrige HRV erhöht den Grundstress leicht.
        let hrvAdjustment = max(0, -(hrvZScore ?? 0)) * 6

        let timeline: [StressPoint] = byHour.keys.sorted().compactMap { hour in
            guard let values = byHour[hour], let avg = Stats.mean(values.map(\.bpm)) else { return nil }
            let hourEnd = hour.addingTimeInterval(3600)
            let isActivity = workouts.contains { $0.start < hourEnd && $0.end > hour }
            let hrr = (avg - restingHeartRate) / reserve
            let level = Stats.normalize(hrr, from: 0.05, to: 0.40) * 100 + hrvAdjustment
            return StressPoint(hour: hour, level: Stats.clamp(level, 0, 100), isActivity: isActivity)
        }

        let rest = timeline.filter { !$0.isActivity }.map(\.level)
        guard let average = Stats.mean(rest) else { return nil }
        return StressResult(
            average: Int(average.rounded()),
            peak: Int((rest.max() ?? average).rounded()),
            timeline: timeline
        )
    }
}

/// Energie-Level: wie viel „Akku“ für den restlichen Tag übrig ist.
public enum EnergyCalculator {
    public static func energy(recovery: Int?, sleep: Int?, strain: Int, stress: Int?) -> Int? {
        guard let recovery else { return nil }
        let start = Double(recovery) * 0.7 + Double(sleep ?? recovery) * 0.3
        let drain = Double(strain) * 0.45 + Double(stress ?? 0) * 0.15
        return Int(Stats.clamp(start - drain + 10, 0, 100).rounded())
    }
}
