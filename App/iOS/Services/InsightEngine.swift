import Foundation
import HealthFamCore

struct Insight: Identifiable, Hashable {
    enum Kind { case positive, neutral, warning }

    var id: String
    var title: String
    var message: String
    var symbolName: String
    var kind: Kind
}

/// Regelbasierter Coach: formuliert verständliche Hinweise aus den Scores.
enum InsightEngine {
    static func insights(for analysis: DailyAnalysis, history: [DailyAnalysis]) -> [Insight] {
        var result: [Insight] = []

        if let recovery = analysis.recovery {
            if recovery.isCalibrating {
                result.append(Insight(
                    id: "calibrating",
                    title: "Kalibrierung läuft",
                    message: "Trage deine Apple Watch auch nachts. Nach etwa einer Woche kennt HealthFam deine persönlichen Normalwerte.",
                    symbolName: "hourglass",
                    kind: .neutral
                ))
            } else {
                switch recovery.level {
                case .high:
                    result.append(Insight(
                        id: "recovery-high",
                        title: "Grünes Licht",
                        message: "Deine Erholung ist hoch. Ideal für ein intensives Training – Ziel-Strain heute: \(analysis.strainTarget.description).",
                        symbolName: "bolt.heart",
                        kind: .positive
                    ))
                case .moderate:
                    result.append(Insight(
                        id: "recovery-moderate",
                        title: "Moderat belasten",
                        message: "Zone-2-Training oder Technikeinheiten passen heute gut. Ziel-Strain: \(analysis.strainTarget.description).",
                        symbolName: "figure.walk",
                        kind: .neutral
                    ))
                case .low:
                    result.append(Insight(
                        id: "recovery-low",
                        title: "Erholung priorisieren",
                        message: "Dein Körper zeigt Belastungszeichen. Leichte Bewegung, früh schlafen und ausreichend trinken helfen.",
                        symbolName: "bed.double",
                        kind: .warning
                    ))
                }
            }
        }

        if let temp = analysis.metrics.wristTemperature, let base = analysis.baseline.wristTemperature, temp - base.mean > 0.5 {
            result.append(Insight(
                id: "temperature",
                title: "Erhöhte Temperatur",
                message: String(format: "Deine Handgelenkstemperatur liegt %.1f °C über deinem Normalwert. Das kann auf einen beginnenden Infekt hindeuten.", temp - base.mean),
                symbolName: "thermometer.medium",
                kind: .warning
            ))
        }

        if let sleep = analysis.sleep {
            let debt = sleep.need - sleep.asleep
            if debt > 3600 {
                result.append(Insight(
                    id: "sleep-debt",
                    title: "Schlafdefizit",
                    message: "Dir fehlen \(Formatters.duration(debt)) Schlaf. Versuche heute etwa 30 Minuten früher ins Bett zu gehen.",
                    symbolName: "moon.zzz",
                    kind: .warning
                ))
            } else if sleep.score >= 85 {
                result.append(Insight(
                    id: "sleep-great",
                    title: "Starke Nacht",
                    message: "Du hast deinen Schlafbedarf gedeckt – das zahlt direkt auf deine Erholung ein.",
                    symbolName: "moon.stars",
                    kind: .positive
                ))
            }
        }

        let lastWeek = history.suffix(8).dropLast()
        let hrvTrend = lastWeek.compactMap(\.metrics.hrv)
        if hrvTrend.count >= 5, let current = analysis.metrics.hrv, let avg = Stats.mean(hrvTrend), let base = analysis.baseline.hrv {
            if avg < base.mean * 0.9 && current < base.mean {
                result.append(Insight(
                    id: "hrv-trend",
                    title: "HRV-Trend sinkt",
                    message: "Deine HRV liegt seit einigen Tagen unter deinem Schnitt. Achte auf Regeneration und reduziere die Intensität.",
                    symbolName: "chart.line.downtrend.xyaxis",
                    kind: .warning
                ))
            } else if avg > base.mean * 1.08 {
                result.append(Insight(
                    id: "hrv-up",
                    title: "Fitness verbessert sich",
                    message: "Deine HRV ist im Wochenschnitt gestiegen – ein Zeichen guter Anpassung.",
                    symbolName: "chart.line.uptrend.xyaxis",
                    kind: .positive
                ))
            }
        }

        if analysis.strain.score > analysis.strainTarget.upper + 10 {
            result.append(Insight(
                id: "overreach",
                title: "Über dem Ziel",
                message: "Dein Strain liegt deutlich über der Empfehlung. Plane morgen bewusst Erholung ein.",
                symbolName: "exclamationmark.triangle",
                kind: .warning
            ))
        }

        if let stress = analysis.stress, stress.level == .high {
            result.append(Insight(
                id: "stress",
                title: "Viel Stress heute",
                message: "Ein paar Minuten Atemübung können deinen Puls senken. Probier die Atem-Session im Journal.",
                symbolName: "wind",
                kind: .warning
            ))
        }

        return result
    }
}
