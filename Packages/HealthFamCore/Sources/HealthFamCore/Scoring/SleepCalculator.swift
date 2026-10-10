import Foundation

/// Berechnet den Schlaf-Score (0–100) aus Dauer im Verhältnis zum Schlafbedarf,
/// Effizienz, erholsamen Phasen (Tief + REM) und Regelmäßigkeit.
public enum SleepCalculator {
    /// Schlafbedarf: Ziel plus Zuschlag für die Belastung des Vortages.
    public static func sleepNeed(profile: UserProfile, previousStrain: Int?) -> TimeInterval {
        let base = profile.sleepGoalHours * 3600
        let strainBonus = Double(previousStrain ?? 0) / 100 * 0.75 * 3600
        return base + strainBonus
    }

    public static func calculate(
        session: SleepSession,
        profile: UserProfile,
        baseline: PersonalBaseline,
        previousStrain: Int?,
        calendar: Calendar = .current
    ) -> SleepResult? {
        let asleep = session.asleepDuration
        guard asleep > 0 else { return nil }

        let need = sleepNeed(profile: profile, previousStrain: previousStrain)
        var parts: [(score: Double, weight: Double)] = []
        var contributors: [ScoreContributor] = []

        let durationScore = Stats.normalize(asleep / need, from: 0.5, to: 1.0)
        parts.append((durationScore, 0.5))
        contributors.append(ScoreContributor(
            name: "Dauer",
            value: Formatters.duration(asleep),
            baseline: "Bedarf \(Formatters.duration(need))",
            impact: durationScore * 2 - 1
        ))

        let efficiency = session.efficiency
        let efficiencyScore = Stats.normalize(efficiency, from: 0.70, to: 0.92)
        parts.append((efficiencyScore, 0.15))
        contributors.append(ScoreContributor(
            name: "Effizienz",
            value: "\(Int((efficiency * 100).rounded())) %",
            impact: efficiencyScore * 2 - 1
        ))

        if let ratio = session.restorativeRatio {
            let restorative = Stats.normalize(ratio, from: 0.20, to: 0.40)
            parts.append((restorative, 0.2))
            contributors.append(ScoreContributor(
                name: "Tief- & REM-Schlaf",
                value: "\(Int((ratio * 100).rounded())) %",
                baseline: "Ziel ≥ 40 %",
                impact: restorative * 2 - 1
            ))
        }

        if let start = session.start, let base = baseline.bedtimeMinutes {
            let deviation = abs(PersonalBaseline.bedtimeMinutes(start, calendar: calendar) - base.mean)
            let consistency = 1 - Stats.normalize(deviation, from: 15, to: 120)
            parts.append((consistency, 0.15))
            contributors.append(ScoreContributor(
                name: "Regelmäßigkeit",
                value: "±\(Int(deviation.rounded())) min",
                baseline: "Übliche Einschlafzeit",
                impact: consistency * 2 - 1
            ))
        }

        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let weighted = parts.reduce(0) { $0 + $1.score * $1.weight } / totalWeight
        let score = Int(Stats.clamp(weighted * 100, 0, 100).rounded())

        return SleepResult(
            score: score,
            asleep: asleep,
            need: need,
            efficiency: efficiency,
            restorativeRatio: session.restorativeRatio,
            contributors: contributors
        )
    }
}
