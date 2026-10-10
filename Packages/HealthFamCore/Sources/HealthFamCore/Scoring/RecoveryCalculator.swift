import Foundation

/// Berechnet den Recovery-Score (0–100) aus HRV, Ruhepuls, Atemfrequenz,
/// Handgelenkstemperatur und Schlaf – jeweils relativ zur persönlichen Baseline.
public enum RecoveryCalculator {
    public static func calculate(
        metrics: DailyMetrics,
        baseline: PersonalBaseline,
        sleepScore: Int?
    ) -> RecoveryResult? {
        guard metrics.hrv != nil || metrics.restingHeartRate != nil else { return nil }

        var composite = 0.0
        var totalWeight = 0.0
        var contributors: [ScoreContributor] = []
        var calibrating = false

        if let hrv = metrics.hrv {
            if let base = baseline.hrv {
                let z = Stats.clamp(base.zScore(hrv), -3, 3)
                composite += 0.45 * z
                totalWeight += 0.45
                contributors.append(ScoreContributor(
                    name: "HRV",
                    value: "\(Int(hrv.rounded())) ms",
                    baseline: "Ø \(Int(base.mean.rounded())) ms",
                    impact: z / 2
                ))
            } else {
                calibrating = true
                contributors.append(ScoreContributor(name: "HRV", value: "\(Int(hrv.rounded())) ms", impact: 0))
            }
        }

        if let rhr = metrics.restingHeartRate {
            if let base = baseline.restingHeartRate {
                // Niedrigerer Ruhepuls = bessere Erholung.
                let z = Stats.clamp(-base.zScore(rhr), -3, 3)
                composite += 0.25 * z
                totalWeight += 0.25
                contributors.append(ScoreContributor(
                    name: "Ruhepuls",
                    value: "\(Int(rhr.rounded())) bpm",
                    baseline: "Ø \(Int(base.mean.rounded())) bpm",
                    impact: z / 2
                ))
            } else {
                calibrating = true
                contributors.append(ScoreContributor(name: "Ruhepuls", value: "\(Int(rhr.rounded())) bpm", impact: 0))
            }
        }

        if let rr = metrics.respiratoryRate, let base = baseline.respiratoryRate {
            // Eine erhöhte Atemfrequenz deutet auf Belastung oder Infekt hin.
            let z = Stats.clamp(-max(0, base.zScore(rr)), -3, 0)
            composite += 0.1 * z
            totalWeight += 0.1
            contributors.append(ScoreContributor(
                name: "Atemfrequenz",
                value: String(format: "%.1f /min", rr),
                baseline: String(format: "Ø %.1f /min", base.mean),
                impact: z / 2
            ))
        }

        if let temp = metrics.wristTemperature, let base = baseline.wristTemperature {
            let delta = temp - base.mean
            // Abweichungen über ±0,3 °C werden zunehmend negativ gewertet.
            let penalty = -Stats.clamp((abs(delta) - 0.3) / 0.4, 0, 2)
            composite += 0.05 * penalty
            totalWeight += 0.05
            contributors.append(ScoreContributor(
                name: "Temperatur",
                value: String(format: "%+.1f °C", delta),
                baseline: "Baseline",
                impact: penalty / 2
            ))
        }

        if let sleepScore {
            let s = Stats.clamp((Double(sleepScore) - 70) / 15, -3, 2)
            composite += 0.15 * s
            totalWeight += 0.15
            contributors.append(ScoreContributor(name: "Schlaf", value: "\(sleepScore) %", impact: s / 2))
        }

        let normalized = totalWeight > 0 ? composite / totalWeight : 0
        let raw = 100 * Stats.sigmoid(0.45 + 1.4 * normalized)
        let score = Int(Stats.clamp(raw, 1, 99).rounded())

        return RecoveryResult(
            score: score,
            level: ScoreLevel(score: score),
            contributors: contributors,
            isCalibrating: calibrating
        )
    }

    /// Empfohlener Strain-Bereich abhängig von der Erholung.
    public static func strainTarget(for recovery: Int?) -> StrainTarget {
        guard let recovery else { return StrainTarget(lower: 35, upper: 60) }
        switch recovery {
        case ..<34: return StrainTarget(lower: 15, upper: 35)
        case 34..<67: return StrainTarget(lower: 35, upper: 60)
        default: return StrainTarget(lower: 55, upper: 85)
        }
    }
}
