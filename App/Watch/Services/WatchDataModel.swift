import Foundation
import HealthFamCore

/// Tagesstand für die Watch: bevorzugt vom iPhone, sonst lokal aus HealthKit berechnet.
@MainActor
final class WatchDataModel: ObservableObject {
    @Published private(set) var local: DailyAnalysis?
    @Published private(set) var isLoading = false

    private let connectivity = WatchConnectivityManager.shared

    struct Summary {
        var recovery: Int?
        var strain: Int
        var target: StrainTarget
        var sleep: Int?
        var sleepDuration: TimeInterval?
        var stress: Int?
        var energy: Int?
        var hrv: Double?
        var restingHeartRate: Double?
        var profile: UserProfile
    }

    var summary: Summary? {
        if let snapshot = connectivity.snapshot, Calendar.current.isDateInToday(snapshot.day) {
            return Summary(
                recovery: snapshot.recovery,
                strain: max(snapshot.strain, local?.strain.score ?? 0),
                target: snapshot.strainTarget,
                sleep: snapshot.sleep,
                sleepDuration: snapshot.sleepDuration,
                stress: snapshot.stress,
                energy: snapshot.energy,
                hrv: snapshot.hrv,
                restingHeartRate: snapshot.restingHeartRate ?? snapshot.restingHeartRateBaseline,
                profile: snapshot.profile
            )
        }
        guard let local else { return nil }
        return Summary(
            recovery: local.recovery?.score,
            strain: local.strain.score,
            target: local.strainTarget,
            sleep: local.sleep?.score,
            sleepDuration: local.sleep?.asleep,
            stress: local.stress?.average,
            energy: local.energy,
            hrv: local.metrics.hrv,
            restingHeartRate: local.metrics.restingHeartRate ?? local.baseline.restingHeartRate?.mean,
            profile: connectivity.snapshot?.profile ?? UserProfile()
        )
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await HealthKitService.shared.requestAuthorization()
            let history = try await HealthKitService.shared.fetchHistory(days: 21)
            let profile = connectivity.snapshot?.profile ?? UserProfile()
            local = HealthAnalyzer.analyze(history: history, profile: profile).last
        } catch {
            // Ohne lokale Daten wird nur der iPhone-Stand angezeigt.
        }
    }
}
