import Foundation

/// Alle berechneten Werte eines Tages.
public struct DailyAnalysis: Codable, Hashable, Sendable, Identifiable {
    public var metrics: DailyMetrics
    public var baseline: PersonalBaseline
    public var recovery: RecoveryResult?
    public var strain: StrainResult
    public var strainTarget: StrainTarget
    public var sleep: SleepResult?
    public var stress: StressResult?
    public var energy: Int?

    public var id: Date { metrics.day }
    public var day: Date { metrics.day }
}

public enum HealthAnalyzer {
    public static func analyze(
        history: [DailyMetrics],
        profile: UserProfile,
        calendar: Calendar = .current
    ) -> [DailyAnalysis] {
        let sorted = history.sorted { $0.day < $1.day }
        var previousStrain: Int?
        var results: [DailyAnalysis] = []

        for metrics in sorted {
            let baseline = PersonalBaseline.compute(from: sorted, before: metrics.day, calendar: calendar)
            let resting = metrics.restingHeartRate ?? baseline.restingHeartRate?.mean ?? 60

            let sleep = metrics.sleep.flatMap {
                SleepCalculator.calculate(
                    session: $0,
                    profile: profile,
                    baseline: baseline,
                    previousStrain: previousStrain,
                    calendar: calendar
                )
            }
            let recovery = RecoveryCalculator.calculate(metrics: metrics, baseline: baseline, sleepScore: sleep?.score)
            let strain = StrainCalculator.calculate(
                samples: metrics.heartRateSamples,
                restingHeartRate: resting,
                maxHeartRate: profile.maxHeartRate,
                sex: profile.sex,
                steps: metrics.steps,
                activeEnergy: metrics.activeEnergy
            )
            let hrvZ = both(metrics.hrv, baseline.hrv).map { pair in pair.1.zScore(pair.0) }
            let stress = StressCalculator.calculate(
                samples: metrics.heartRateSamples,
                restingHeartRate: resting,
                maxHeartRate: profile.maxHeartRate,
                workouts: metrics.workouts,
                sleep: metrics.sleep,
                hrvZScore: hrvZ,
                calendar: calendar
            )

            results.append(DailyAnalysis(
                metrics: metrics,
                baseline: baseline,
                recovery: recovery,
                strain: strain,
                strainTarget: RecoveryCalculator.strainTarget(for: recovery?.score),
                sleep: sleep,
                stress: stress,
                energy: EnergyCalculator.energy(
                    recovery: recovery?.score,
                    sleep: sleep?.score,
                    strain: strain.score,
                    stress: stress?.average
                )
            ))
            previousStrain = strain.score
        }
        return results
    }

    /// Strain eines einzelnen Workouts (für Trainingslisten und die Watch).
    public static func workoutStrain(
        _ workout: WorkoutSummary,
        samples: [HeartRateSample],
        restingHeartRate: Double,
        profile: UserProfile
    ) -> Int {
        let inWorkout = samples.filter { workout.contains($0.date) }
        let result = StrainCalculator.trimp(
            samples: inWorkout,
            restingHeartRate: restingHeartRate,
            maxHeartRate: profile.maxHeartRate,
            sex: profile.sex
        )
        return StrainCalculator.score(forTRIMP: result.trimp)
    }
}

private func both<A, B>(_ a: A?, _ b: B?) -> (A, B)? {
    guard let a, let b else { return nil }
    return (a, b)
}
