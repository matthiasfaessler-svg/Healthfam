import SwiftUI
import HealthFamCore

struct TrendsView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @State private var range = 30

    enum Metric: String, CaseIterable, Identifiable {
        case recovery = "Recovery"
        case strain = "Strain"
        case sleep = "Schlaf"
        case hrv = "HRV"
        case restingHeartRate = "Ruhepuls"
        case stress = "Stress"
        case steps = "Schritte"
        case vo2Max = "VO₂max"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .recovery, .hrv: return Theme.recovery
            case .strain, .vo2Max: return Theme.strain
            case .sleep: return Theme.sleep
            case .restingHeartRate: return Theme.heart
            case .stress: return Theme.stress
            case .steps: return Theme.energy
            }
        }

        var unit: String {
            switch self {
            case .recovery, .strain, .sleep: return "%"
            case .hrv: return "ms"
            case .restingHeartRate: return "bpm"
            case .stress, .steps: return ""
            case .vo2Max: return "ml/kg·min"
            }
        }

        var style: TrendChart.Style {
            switch self {
            case .recovery, .strain, .sleep, .steps, .stress: return .bar
            case .hrv, .restingHeartRate, .vo2Max: return .line
            }
        }

        func value(_ a: DailyAnalysis) -> Double? {
            switch self {
            case .recovery: return a.recovery.map { Double($0.score) }
            case .strain: return Double(a.strain.score)
            case .sleep: return a.sleep.map { Double($0.score) }
            case .hrv: return a.metrics.hrv
            case .restingHeartRate: return a.metrics.restingHeartRate
            case .stress: return a.stress.map { Double($0.average) }
            case .steps: return a.metrics.steps > 0 ? a.metrics.steps : nil
            case .vo2Max: return a.metrics.vo2Max
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Picker("Zeitraum", selection: $range) {
                        Text("7 Tage").tag(7)
                        Text("30 Tage").tag(30)
                        Text("60 Tage").tag(60)
                    }
                    .pickerStyle(.segmented)

                    WeeklySummaryCard(days: dataStore.recent(7))

                    ForEach(Metric.allCases) { metric in
                        metricCard(metric)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Trends")
        }
    }

    private func metricCard(_ metric: Metric) -> some View {
        let days = dataStore.recent(range)
        let points = days.compactMap { a in metric.value(a).map { TrendPoint(date: a.day, value: $0) } }
        let average = Stats.mean(points.map(\.value))
        let previous = Array(dataStore.analyses.dropLast(range).suffix(range)).compactMap(metric.value)
        let previousAverage = Stats.mean(previous)

        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(metric.rawValue).font(.headline)
                    Spacer()
                    if let average {
                        Text("Ø \(Formatters.number(average, decimals: metric == .vo2Max ? 1 : 0)) \(metric.unit)")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    if let average, let previousAverage, previousAverage != 0 {
                        let change = (average - previousAverage) / previousAverage * 100
                        Text(String(format: "%+.0f %%", change))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
                if points.isEmpty {
                    Text("Keine Daten im Zeitraum").font(.subheadline).foregroundStyle(Theme.secondaryText)
                } else {
                    TrendChart(
                        points: points,
                        color: metric.color,
                        style: metric.style,
                        baseline: metric.style == .line ? average : nil,
                        yDomain: metric.unit == "%" ? 0...100 : nil,
                        height: 150
                    )
                }
            }
        }
    }
}

struct WeeklySummaryCard: View {
    var days: [DailyAnalysis]

    var body: some View {
        let recovery = Stats.mean(days.compactMap { $0.recovery.map { Double($0.score) } })
        let strain = Stats.mean(days.map { Double($0.strain.score) })
        let sleep = Stats.mean(days.compactMap { $0.sleep?.asleep })
        let workouts = days.reduce(0) { $0 + $1.metrics.workouts.count }

        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Deine Woche").font(.headline)
                HStack {
                    summary("Recovery", recovery.map { "\(Int($0.rounded())) %" }, Theme.recovery)
                    summary("Strain", strain.map { "\(Int($0.rounded())) %" }, Theme.strain)
                    summary("Schlaf", sleep.map { Formatters.duration($0) }, Theme.sleep)
                    summary("Trainings", "\(workouts)", Theme.energy)
                }
            }
        }
    }

    private func summary(_ title: String, _ value: String?, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(value ?? "–").font(.subheadline.weight(.bold).monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
