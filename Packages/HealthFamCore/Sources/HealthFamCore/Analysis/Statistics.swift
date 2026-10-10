import Foundation

public enum Stats {
    public static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    public static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count > 1, let m = mean(values) else { return nil }
        let variance = values.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(values.count - 1)
        return variance.squareRoot()
    }

    public static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    public static func clamp<T: Comparable>(_ value: T, _ lower: T, _ upper: T) -> T {
        min(max(value, lower), upper)
    }

    public static func sigmoid(_ x: Double) -> Double {
        1 / (1 + exp(-x))
    }

    /// Lineare Interpolation von `value` aus [inLow, inHigh] auf [0, 1], begrenzt.
    public static func normalize(_ value: Double, from inLow: Double, to inHigh: Double) -> Double {
        guard inHigh != inLow else { return 0 }
        return clamp((value - inLow) / (inHigh - inLow), 0, 1)
    }
}

/// Mittelwert und Streuung einer Messgröße über ein rollierendes Fenster.
public struct MetricBaseline: Codable, Hashable, Sendable {
    public var mean: Double
    public var standardDeviation: Double
    public var sampleCount: Int

    public init(mean: Double, standardDeviation: Double, sampleCount: Int) {
        self.mean = mean
        self.standardDeviation = standardDeviation
        self.sampleCount = sampleCount
    }

    /// Erzeugt eine Baseline, sofern genügend Werte vorliegen. Die Streuung wird
    /// nach unten begrenzt, damit kleine Schwankungen nicht überbewertet werden.
    public init?(values: [Double], minimumCount: Int = 3, relativeFloor: Double = 0.05) {
        guard values.count >= minimumCount, let m = Stats.mean(values) else { return nil }
        let sd = Stats.standardDeviation(values) ?? 0
        self.init(mean: m, standardDeviation: max(sd, abs(m) * relativeFloor, 0.0001), sampleCount: values.count)
    }

    public func zScore(_ value: Double) -> Double {
        (value - mean) / standardDeviation
    }
}
