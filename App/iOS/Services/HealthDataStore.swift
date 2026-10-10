import Foundation
import SwiftUI
import HealthFamCore

/// Lädt die Daten aus Apple Health (oder Demo-Daten), berechnet alle Scores
/// und stellt sie den Views zur Verfügung.
@MainActor
final class HealthDataStore: ObservableObject {
    @Published private(set) var analyses: [DailyAnalysis] = []
    @Published var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastUpdated: Date?

    private let health = HealthKitService.shared
    private let settings: AppSettings
    private let connectivity: PhoneConnectivity
    private var refreshTask: Task<Void, Never>?

    static let historyDays = 60

    init(settings: AppSettings, connectivity: PhoneConnectivity) {
        self.settings = settings
        self.connectivity = connectivity
        loadCache()
    }

    var selected: DailyAnalysis? {
        analyses.first { Calendar.current.isDate($0.day, inSameDayAs: selectedDay) }
    }

    var today: DailyAnalysis? {
        analyses.first { Calendar.current.isDateInToday($0.day) }
    }

    func analysis(for day: Date) -> DailyAnalysis? {
        analyses.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
    }

    func recent(_ days: Int) -> [DailyAnalysis] {
        Array(analyses.suffix(days))
    }

    var recoveryByDay: [Date: Int] {
        Dictionary(uniqueKeysWithValues: analyses.compactMap { a in a.recovery.map { (a.day, $0.score) } })
    }

    // MARK: - Laden

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let metrics: [DailyMetrics]
            if settings.useDemoData {
                metrics = DemoDataGenerator.generate(days: Self.historyDays)
            } else {
                metrics = try await health.fetchHistory(days: Self.historyDays)
                applyHealthCharacteristics()
            }
            let profile = settings.profile
            let results = await Task.detached(priority: .userInitiated) {
                HealthAnalyzer.analyze(history: metrics, profile: profile)
            }.value
            analyses = results
            lastUpdated = Date()
            lastError = nil
            saveCache()
            if let today {
                connectivity.send(WatchSnapshot(analysis: today, profile: profile))
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func applyHealthCharacteristics() {
        let characteristics = health.profileCharacteristics()
        var profile = settings.profile
        var changed = false
        if let age = characteristics.age, profile.age != age {
            profile.age = age
            changed = true
        }
        if let sex = characteristics.sex, profile.sex != sex, !settings.sexEditedManually {
            profile.sex = sex
            changed = true
        }
        if changed { settings.profile = profile }
    }

    func startBackgroundUpdates() {
        guard !settings.useDemoData else { return }
        health.startObserving { [weak self] in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Cache (für schnellen App-Start)

    private var cacheURL: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("analyses.json")
    }

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let cached = try? JSONDecoder().decode([DailyAnalysis].self, from: data) else { return }
        analyses = cached
    }

    private func saveCache() {
        // Rohdaten der Herzfrequenz werden für den Cache weggelassen.
        let slim = analyses.map { analysis -> DailyAnalysis in
            var copy = analysis
            copy.metrics.heartRateSamples = []
            return copy
        }
        if let data = try? JSONEncoder().encode(slim) {
            try? data.write(to: cacheURL, options: .atomic)
        }
    }
}
