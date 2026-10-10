import Foundation

public enum Formatters {
    /// "7 h 32 min"
    public static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((interval / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        return minutes == 0 ? "\(hours) h" : "\(hours) h \(minutes) min"
    }

    /// "1:05:12" bzw. "05:12"
    public static func clock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    public static func number(_ value: Double, decimals: Int = 0) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = decimals
        formatter.minimumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// Kompakter Tagesstand, der vom iPhone an die Apple Watch gesendet wird.
public struct WatchSnapshot: Codable, Hashable, Sendable {
    public var day: Date
    public var recovery: Int?
    public var strain: Int
    public var strainTarget: StrainTarget
    public var sleep: Int?
    public var sleepDuration: TimeInterval?
    public var stress: Int?
    public var energy: Int?
    public var hrv: Double?
    public var restingHeartRate: Double?
    public var restingHeartRateBaseline: Double?
    public var profile: UserProfile

    public init(analysis: DailyAnalysis, profile: UserProfile) {
        day = analysis.day
        recovery = analysis.recovery?.score
        strain = analysis.strain.score
        strainTarget = analysis.strainTarget
        sleep = analysis.sleep?.score
        sleepDuration = analysis.sleep?.asleep
        stress = analysis.stress?.average
        energy = analysis.energy
        hrv = analysis.metrics.hrv
        restingHeartRate = analysis.metrics.restingHeartRate
        restingHeartRateBaseline = analysis.baseline.restingHeartRate?.mean
        self.profile = profile
    }

    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decode(_ data: Data) throws -> WatchSnapshot {
        try JSONDecoder().decode(WatchSnapshot.self, from: data)
    }
}
