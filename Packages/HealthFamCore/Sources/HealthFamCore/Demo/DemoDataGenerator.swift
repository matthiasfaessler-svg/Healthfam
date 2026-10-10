import Foundation

/// Deterministischer Zufallsgenerator (SplitMix64), damit Demo-Daten stabil bleiben.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func gaussian(mean: Double, sd: Double) -> Double {
        let u1 = Double.random(in: Double.ulpOfOne...1, using: &self)
        let u2 = Double.random(in: 0...1, using: &self)
        return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// Erzeugt realistische Beispieldaten – für den Simulator, Previews und
/// zum Ausprobieren der App ohne Apple Watch.
public enum DemoDataGenerator {
    public static func generate(
        days: Int = 60,
        endingAt end: Date = Date(),
        seed: UInt64 = 42,
        calendar: Calendar = .current
    ) -> [DailyMetrics] {
        var rng = SeededGenerator(seed: seed)
        let today = calendar.startOfDay(for: end)
        var result: [DailyMetrics] = []
        var fatigue = 0.0

        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let isToday = offset == 0
            let weekday = calendar.component(.weekday, from: day)
            let trains = [2, 4, 6, 7].contains(weekday) && Double.random(in: 0...1, using: &rng) > 0.15

            let hrv = max(20, rng.gaussian(mean: 58 - fatigue * 8, sd: 7))
            let rhr = max(42, rng.gaussian(mean: 53 + fatigue * 3, sd: 1.8))
            let sleep = makeSleep(day: day, rng: &rng, calendar: calendar)

            var samples: [HeartRateSample] = []
            var workouts: [WorkoutSummary] = []
            let currentHour = isToday ? calendar.component(.hour, from: end) : 23

            // Tagsüber alle 10 Minuten ein Messwert.
            for minute in stride(from: 7 * 60, to: min(23, currentHour + 1) * 60, by: 10) {
                guard let date = calendar.date(byAdding: .minute, value: minute, to: day) else { continue }
                let hour = minute / 60
                let busy = (9...17).contains(hour) ? 8.0 : 0
                samples.append(HeartRateSample(date: date, bpm: rng.gaussian(mean: rhr + 18 + busy, sd: 6)))
            }

            if trains, currentHour >= 18,
               let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) {
                let minutes = Int.random(in: 35...75, using: &rng)
                let intensity = Double.random(in: 0.6...0.85, using: &rng)
                let maxHR = 190.0
                var hrs: [Double] = []
                for m in 0..<minutes {
                    let warmup = min(1, Double(m) / 8)
                    let bpm = rhr + (maxHR - rhr) * intensity * warmup + rng.gaussian(mean: 0, sd: 4)
                    hrs.append(bpm)
                    samples.append(HeartRateSample(date: start.addingTimeInterval(Double(m) * 60), bpm: bpm))
                }
                let kinds: [(String, String)] = [("Laufen", "figure.run"), ("Krafttraining", "dumbbell"), ("Radfahren", "figure.outdoor.cycle"), ("HIIT", "figure.highintensity.intervaltraining")]
                let kind = kinds[Int.random(in: 0..<kinds.count, using: &rng)]
                workouts.append(WorkoutSummary(
                    id: stableID(&rng),
                    activityName: kind.0,
                    symbolName: kind.1,
                    start: start,
                    end: start.addingTimeInterval(Double(minutes) * 60),
                    activeEnergy: Double(minutes) * Double.random(in: 8...12, using: &rng),
                    distanceMeters: kind.0 == "Laufen" ? Double(minutes) * 170 : nil,
                    averageHeartRate: Stats.mean(hrs),
                    maxHeartRate: hrs.max()
                ))
                fatigue = min(1.5, fatigue + intensity * 0.6)
            } else {
                fatigue = max(0, fatigue - 0.45)
            }

            samples.sort { $0.date < $1.date }
            let dayFraction = isToday ? Double(currentHour) / 24 : 1
            result.append(DailyMetrics(
                day: day,
                hrv: hrv,
                restingHeartRate: rhr,
                respiratoryRate: rng.gaussian(mean: 14.6 + fatigue * 0.3, sd: 0.4),
                oxygenSaturation: Stats.clamp(rng.gaussian(mean: 0.97, sd: 0.008), 0.9, 1),
                wristTemperature: rng.gaussian(mean: 36.3, sd: 0.15),
                vo2Max: 47 + Double(days - offset) * 0.02,
                steps: max(0, rng.gaussian(mean: 9500, sd: 2800)) * dayFraction,
                activeEnergy: (max(150, rng.gaussian(mean: 480, sd: 120)) + workouts.reduce(0) { $0 + ($1.activeEnergy ?? 0) }) * dayFraction,
                basalEnergy: 1700 * dayFraction,
                sleep: sleep,
                heartRateSamples: samples,
                workouts: workouts,
                nutrition: NutritionSummary(
                    calories: max(0, rng.gaussian(mean: 2150, sd: 300)) * dayFraction,
                    protein: max(0, rng.gaussian(mean: 115, sd: 25)) * dayFraction,
                    carbohydrates: max(0, rng.gaussian(mean: 230, sd: 50)) * dayFraction,
                    fat: max(0, rng.gaussian(mean: 75, sd: 15)) * dayFraction,
                    water: max(0, rng.gaussian(mean: 2200, sd: 400)) * dayFraction
                )
            ))
        }
        return result
    }

    private static func stableID(_ rng: inout SeededGenerator) -> UUID {
        let suffix = String(rng.next() & 0xFFFF_FFFF_FFFF, radix: 16, uppercase: true)
        let padded = String(repeating: "0", count: 12 - suffix.count) + suffix
        return UUID(uuidString: "00000000-0000-4000-8000-\(padded)") ?? UUID()
    }

    private static func makeSleep(day: Date, rng: inout SeededGenerator, calendar: Calendar) -> SleepSession? {
        guard let midnight = calendar.date(byAdding: .minute, value: Int(rng.gaussian(mean: -50, sd: 30)), to: day) else { return nil }
        var cursor = midnight
        var segments: [SleepSegment] = [SleepSegment(start: cursor, end: cursor.addingTimeInterval(600), stage: .awake)]
        cursor = cursor.addingTimeInterval(600)

        let cycles = Int.random(in: 4...6, using: &rng)
        for cycle in 0..<cycles {
            // Tiefschlaf überwiegt zu Beginn, REM gegen Morgen.
            let deep = max(5, rng.gaussian(mean: cycle < 2 ? 28 : 8, sd: 6))
            let core = max(20, rng.gaussian(mean: 45, sd: 10))
            let rem = max(5, rng.gaussian(mean: cycle < 2 ? 12 : 28, sd: 6))
            for (stage, minutes) in [(SleepStage.core, core / 2), (.deep, deep), (.core, core / 2), (.rem, rem)] {
                let end = cursor.addingTimeInterval(minutes * 60)
                segments.append(SleepSegment(start: cursor, end: end, stage: stage))
                cursor = end
            }
            if Double.random(in: 0...1, using: &rng) > 0.6 {
                let end = cursor.addingTimeInterval(Double.random(in: 2...8, using: &rng) * 60)
                segments.append(SleepSegment(start: cursor, end: end, stage: .awake))
                cursor = end
            }
        }
        return SleepSession(segments: segments)
    }
}
