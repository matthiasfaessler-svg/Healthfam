import Foundation

/// Persönliche Normalwerte, berechnet aus den vorangegangenen Tagen.
/// Alle Scores vergleichen den aktuellen Tag mit dieser Baseline –
/// so wie Bevel es tut, statt mit Bevölkerungsdurchschnitten.
public struct PersonalBaseline: Codable, Hashable, Sendable {
    public var hrv: MetricBaseline?
    public var restingHeartRate: MetricBaseline?
    public var respiratoryRate: MetricBaseline?
    public var wristTemperature: MetricBaseline?
    public var sleepDuration: MetricBaseline?
    /// Einschlafzeit in Minuten relativ zu Mitternacht (z. B. −60 = 23:00).
    public var bedtimeMinutes: MetricBaseline?

    public init(
        hrv: MetricBaseline? = nil,
        restingHeartRate: MetricBaseline? = nil,
        respiratoryRate: MetricBaseline? = nil,
        wristTemperature: MetricBaseline? = nil,
        sleepDuration: MetricBaseline? = nil,
        bedtimeMinutes: MetricBaseline? = nil
    ) {
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.respiratoryRate = respiratoryRate
        self.wristTemperature = wristTemperature
        self.sleepDuration = sleepDuration
        self.bedtimeMinutes = bedtimeMinutes
    }

    /// Berechnet die Baseline aus den `window` Tagen vor `day` (exklusive).
    public static func compute(
        from history: [DailyMetrics],
        before day: Date,
        window: Int = 30,
        calendar: Calendar = .current
    ) -> PersonalBaseline {
        let startOfDay = calendar.startOfDay(for: day)
        guard let windowStart = calendar.date(byAdding: .day, value: -window, to: startOfDay) else {
            return PersonalBaseline()
        }
        let relevant = history.filter { $0.day >= windowStart && $0.day < startOfDay }

        return PersonalBaseline(
            hrv: MetricBaseline(values: relevant.compactMap(\.hrv)),
            restingHeartRate: MetricBaseline(values: relevant.compactMap(\.restingHeartRate)),
            respiratoryRate: MetricBaseline(values: relevant.compactMap(\.respiratoryRate)),
            wristTemperature: MetricBaseline(values: relevant.compactMap(\.wristTemperature), relativeFloor: 0.005),
            sleepDuration: MetricBaseline(values: relevant.compactMap { $0.sleep?.asleepDuration }),
            bedtimeMinutes: MetricBaseline(
                values: relevant.compactMap { $0.sleep?.start.map { bedtimeMinutes($0, calendar: calendar) } },
                relativeFloor: 0
            )
        )
    }

    /// Minuten relativ zur Mitternacht; Zeiten vor 12 Uhr mittags zählen zum
    /// Folgetag (positiv), Zeiten danach zum Vorabend (negativ).
    public static func bedtimeMinutes(_ date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let minutes = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        return minutes >= 12 * 60 ? minutes - 24 * 60 : minutes
    }
}
