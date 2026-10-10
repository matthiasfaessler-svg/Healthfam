import Foundation

public enum SleepStage: String, Codable, Sendable, CaseIterable {
    case awake, rem, core, deep, unspecified, inBed

    public var isAsleep: Bool {
        switch self {
        case .rem, .core, .deep, .unspecified: return true
        case .awake, .inBed: return false
        }
    }

    public var displayName: String {
        switch self {
        case .awake: return "Wach"
        case .rem: return "REM"
        case .core: return "Kernschlaf"
        case .deep: return "Tiefschlaf"
        case .unspecified: return "Schlaf"
        case .inBed: return "Im Bett"
        }
    }
}

public struct SleepSegment: Codable, Hashable, Sendable {
    public var start: Date
    public var end: Date
    public var stage: SleepStage
    /// Kennung der Datenquelle (z. B. Bundle-ID der Apple Watch).
    public var source: String

    public init(start: Date, end: Date, stage: SleepStage, source: String = "default") {
        self.start = start
        self.end = end
        self.stage = stage
        self.source = source
    }

    public var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

public struct SleepSession: Codable, Hashable, Sendable {
    public var segments: [SleepSegment]

    public init(segments: [SleepSegment]) {
        self.segments = segments.sorted { $0.start < $1.start }
    }

    public var start: Date? { segments.map(\.start).min() }
    public var end: Date? { segments.map(\.end).max() }

    public var timeInBed: TimeInterval {
        guard let start, let end else { return 0 }
        return end.timeIntervalSince(start)
    }

    public var asleepDuration: TimeInterval {
        segments.filter { $0.stage.isAsleep }.reduce(0) { $0 + $1.duration }
    }

    public func duration(of stage: SleepStage) -> TimeInterval {
        segments.filter { $0.stage == stage }.reduce(0) { $0 + $1.duration }
    }

    /// Anteil der Zeit im Bett, in der tatsächlich geschlafen wurde.
    public var efficiency: Double {
        guard timeInBed > 0 else { return 0 }
        return min(1, asleepDuration / timeInBed)
    }

    /// Ob Schlafphasen (Kern/Tief/REM) vorliegen – nur mit Apple Watch.
    public var hasStages: Bool {
        segments.contains { [.core, .deep, .rem].contains($0.stage) }
    }

    /// Anteil von Tief- und REM-Schlaf am Gesamtschlaf.
    public var restorativeRatio: Double? {
        guard hasStages, asleepDuration > 0 else { return nil }
        return (duration(of: .deep) + duration(of: .rem)) / asleepDuration
    }
}

/// Fasst einzelne Schlaf-Samples aus Apple Health zu Nächten zusammen.
public enum SleepSessionBuilder {
    /// Maximale Lücke zwischen zwei Segmenten, die noch zur selben Nacht zählt.
    public static let maxGap: TimeInterval = 2 * 3600

    /// Liefert den Hauptschlaf pro Tag (zugeordnet zum Tag des Aufwachens).
    public static func mainSleepByDay(
        from segments: [SleepSegment],
        calendar: Calendar = .current
    ) -> [Date: SleepSession] {
        var result: [Date: SleepSession] = [:]
        for session in sessions(from: segments) {
            guard let end = session.end else { continue }
            let day = calendar.startOfDay(for: end)
            if let existing = result[day], existing.asleepDuration >= session.asleepDuration {
                continue
            }
            result[day] = session
        }
        return result
    }

    /// Gruppiert Segmente zu zusammenhängenden Schlafphasen. Liefern mehrere
    /// Quellen Daten für dieselbe Nacht, wird nur die ergiebigste verwendet,
    /// damit sich Zeiten nicht doppelt addieren.
    public static func sessions(from segments: [SleepSegment]) -> [SleepSession] {
        let sorted = segments.filter { $0.duration > 0 }.sorted { $0.start < $1.start }
        var clusters: [[SleepSegment]] = []
        var clusterEnd: Date = .distantPast

        for segment in sorted {
            if var last = clusters.last, segment.start.timeIntervalSince(clusterEnd) <= maxGap {
                last.append(segment)
                clusters[clusters.count - 1] = last
                clusterEnd = max(clusterEnd, segment.end)
            } else {
                clusters.append([segment])
                clusterEnd = segment.end
            }
        }

        return clusters.compactMap { cluster in
            let bySource = Dictionary(grouping: cluster, by: \.source)
            let best = bySource.max { lhs, rhs in
                score(lhs.value) < score(rhs.value)
            }?.value ?? cluster
            let session = SleepSession(segments: best)
            return session.asleepDuration > 0 || session.timeInBed > 0 ? session : nil
        }
    }

    private static func score(_ segments: [SleepSegment]) -> Double {
        let session = SleepSession(segments: segments)
        // Quellen mit Schlafphasen (Apple Watch) werden bevorzugt.
        return session.asleepDuration + (session.hasStages ? 3600 * 24 : 0)
    }
}
