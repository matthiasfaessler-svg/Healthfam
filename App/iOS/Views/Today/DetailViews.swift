import SwiftUI
import Charts
import HealthFamCore

// MARK: - Recovery

struct RecoveryDetailView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analysis = dataStore.selected, let recovery = analysis.recovery {
                    let color = Theme.recoveryColor(recovery.score)
                    LabeledScoreRing(title: analysis.day.longDate, value: recovery.score, color: color, size: 180, lineWidth: 16)
                        .padding(.top, 12)
                    Text(recovery.headline).font(.headline).multilineTextAlignment(.center)

                    Card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Einflussfaktoren").font(.headline).padding(.bottom, 6)
                            ForEach(recovery.contributors) { ContributorRow(contributor: $0) }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recovery – 30 Tage").font(.headline)
                            TrendChart(
                                points: dataStore.recent(30).compactMap { a in a.recovery.map { TrendPoint(date: a.day, value: Double($0.score)) } },
                                color: color,
                                style: .bar,
                                yDomain: 0...100
                            )
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("HRV – 30 Tage").font(.headline)
                            TrendChart(
                                points: dataStore.recent(30).compactMap { a in a.metrics.hrv.map { TrendPoint(date: a.day, value: $0) } },
                                color: Theme.recovery,
                                baseline: analysis.baseline.hrv?.mean
                            )
                        }
                    }

                    ExplanationCard(text: "Recovery vergleicht deine nächtliche Herzfrequenzvariabilität, deinen Ruhepuls, die Atemfrequenz, die Handgelenkstemperatur und deinen Schlaf mit deinen eigenen Werten der letzten 30 Tage. Eine höhere HRV und ein niedrigerer Ruhepuls als üblich bedeuten, dass dein Nervensystem gut erholt ist.")
                } else {
                    EmptyStateView(symbol: "heart.text.square", title: "Keine Recovery", message: "Für diesen Tag liegen keine HRV- oder Ruhepulsdaten vor. Trage deine Apple Watch im Schlaf.")
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Strain

struct StrainDetailView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analysis = dataStore.selected {
                    let strain = analysis.strain
                    LabeledScoreRing(title: "Ziel \(analysis.strainTarget.description)", value: strain.score, color: Theme.strain, size: 180, lineWidth: 16, target: analysis.strainTarget)
                        .padding(.top, 12)

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Herzfrequenzzonen").font(.headline)
                            let total = max(strain.zones.reduce(0) { $0 + $1.duration }, 1)
                            ForEach(strain.zones.reversed()) { zone in
                                HStack {
                                    Text(zone.name).font(.subheadline).frame(width: 150, alignment: .leading)
                                    GeometryReader { proxy in
                                        Capsule()
                                            .fill(Theme.strain.opacity(0.3 + Double(zone.index) * 0.14))
                                            .frame(width: max(4, proxy.size.width * zone.duration / total))
                                    }
                                    .frame(height: 10)
                                    Text(Formatters.duration(zone.duration)).font(.caption.monospacedDigit()).frame(width: 64, alignment: .trailing)
                                }
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Herzfrequenz").font(.headline)
                            HeartRateChart(samples: analysis.metrics.heartRateSamples, workouts: analysis.metrics.workouts)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Strain – 30 Tage").font(.headline)
                            TrendChart(points: dataStore.recent(30).map { TrendPoint(date: $0.day, value: Double($0.strain.score)) }, color: Theme.strain, style: .bar, yDomain: 0...100)
                        }
                    }

                    HStack(spacing: 12) {
                        MetricTile(title: "TRIMP", value: Formatters.number(strain.trimp), symbol: "bolt.heart", color: Theme.strain)
                        MetricTile(title: "Max. Puls", value: "\(Int(settings.profile.maxHeartRate))", unit: "bpm", symbol: "heart", color: Theme.heart)
                    }

                    ExplanationCard(text: "Strain misst die Belastung deines Herz-Kreislauf-Systems über den ganzen Tag – nicht nur im Training. Zeit in höheren Herzfrequenzzonen zählt überproportional. Das Ziel richtet sich nach deiner Recovery: Bist du gut erholt, verträgst du mehr.")
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Strain")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HeartRateChart: View {
    var samples: [HeartRateSample]
    var workouts: [WorkoutSummary]

    var body: some View {
        if samples.isEmpty {
            Text("Keine Herzfrequenzdaten").font(.subheadline).foregroundStyle(Theme.secondaryText)
        } else {
            Chart {
                ForEach(workouts) { workout in
                    RectangleMark(xStart: .value("Start", workout.start), xEnd: .value("Ende", workout.end))
                        .foregroundStyle(Theme.strain.opacity(0.15))
                }
                ForEach(samples, id: \.date) { sample in
                    LineMark(x: .value("Zeit", sample.date), y: .value("bpm", sample.bpm))
                        .foregroundStyle(Theme.heart)
                        .interpolationMethod(.monotone)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 4)) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 180)
        }
    }
}

// MARK: - Schlaf

struct SleepDetailView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analysis = dataStore.selected, let sleep = analysis.sleep, let session = analysis.metrics.sleep {
                    LabeledScoreRing(title: "Schlaf-Score", value: sleep.score, color: Theme.sleep, size: 180, lineWidth: 16)
                        .padding(.top, 12)

                    HStack(spacing: 12) {
                        MetricTile(title: "Geschlafen", value: Formatters.duration(sleep.asleep), symbol: "moon.fill", color: Theme.sleep, caption: "Bedarf \(Formatters.duration(sleep.need))")
                        MetricTile(
                            title: "Im Bett",
                            value: Formatters.duration(session.timeInBed),
                            symbol: "bed.double.fill",
                            color: Theme.sleep,
                            caption: [session.start, session.end].compactMap { $0?.timeString }.joined(separator: " – ")
                        )
                    }

                    if session.hasStages {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Schlafphasen").font(.headline)
                                Hypnogram(session: session)
                                ForEach([SleepStage.awake, .rem, .core, .deep], id: \.self) { stage in
                                    HStack {
                                        Circle().fill(Theme.stageColor(stage)).frame(width: 10, height: 10)
                                        Text(stage.displayName).font(.subheadline)
                                        Spacer()
                                        Text(Formatters.duration(session.duration(of: stage))).font(.subheadline.monospacedDigit())
                                        Text("\(Int((session.duration(of: stage) / max(session.timeInBed, 1) * 100).rounded())) %")
                                            .font(.caption)
                                            .foregroundStyle(Theme.secondaryText)
                                            .frame(width: 40, alignment: .trailing)
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Einflussfaktoren").font(.headline).padding(.bottom, 6)
                            ForEach(sleep.contributors) { ContributorRow(contributor: $0) }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Schlafdauer – 30 Tage").font(.headline)
                            TrendChart(
                                points: dataStore.recent(30).compactMap { a in a.sleep.map { TrendPoint(date: a.day, value: $0.asleep / 3600) } },
                                color: Theme.sleep,
                                style: .bar,
                                baseline: sleep.need / 3600
                            )
                        }
                    }
                } else {
                    EmptyStateView(symbol: "moon.zzz", title: "Keine Schlafdaten", message: "Aktiviere „Schlaf“ auf deiner Apple Watch und trage sie nachts, um Schlafphasen zu erfassen.")
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Schlaf")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Zeitstrahl der Schlafphasen.
struct Hypnogram: View {
    var session: SleepSession

    private func row(_ stage: SleepStage) -> Int {
        switch stage {
        case .awake, .inBed: return 0
        case .rem: return 1
        case .core, .unspecified: return 2
        case .deep: return 3
        }
    }

    var body: some View {
        Chart {
            ForEach(Array(session.segments.enumerated()), id: \.offset) { _, segment in
                RectangleMark(
                    xStart: .value("Start", segment.start),
                    xEnd: .value("Ende", segment.end),
                    yStart: .value("Phase", row(segment.stage)),
                    yEnd: .value("Phase", row(segment.stage) + 1)
                )
                .foregroundStyle(Theme.stageColor(segment.stage))
                .cornerRadius(3)
            }
        }
        .chartYScale(domain: 0...4)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
        .frame(height: 140)
    }
}

// MARK: - Stress

struct StressDetailView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @State private var showBreathing = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let analysis = dataStore.selected, let stress = analysis.stress {
                    LabeledScoreRing(title: stress.label, value: stress.average, color: Theme.stress, size: 180, lineWidth: 16, suffix: "")
                        .padding(.top, 12)

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Tagesverlauf").font(.headline)
                            Chart(stress.timeline) { point in
                                BarMark(x: .value("Stunde", point.hour, unit: .hour), y: .value("Stress", point.level))
                                    .foregroundStyle(point.isActivity ? Theme.strain : Theme.stress)
                                    .cornerRadius(3)
                            }
                            .chartYScale(domain: 0...100)
                            .frame(height: 180)
                            HStack(spacing: 16) {
                                Label("Stress", systemImage: "circle.fill").foregroundStyle(Theme.stress)
                                Label("Aktivität", systemImage: "circle.fill").foregroundStyle(Theme.strain)
                            }
                            .font(.caption)
                        }
                    }

                    HStack(spacing: 12) {
                        MetricTile(title: "Durchschnitt", value: "\(stress.average)", symbol: "gauge.medium", color: Theme.stress)
                        MetricTile(title: "Spitze", value: "\(stress.peak)", symbol: "arrow.up.to.line", color: Theme.stress)
                    }

                    Button { showBreathing = true } label: {
                        Label("Atemübung starten", systemImage: "wind")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.stress.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    ExplanationCard(text: "Stress wird aus deiner Herzfrequenz in Ruhe geschätzt – also außerhalb von Training und Schlaf. Liegt dein Puls ohne körperliche Aktivität deutlich über dem Ruhepuls, deutet das auf mentale oder physiologische Belastung hin.")
                } else {
                    EmptyStateView(symbol: "waveform.path.ecg", title: "Keine Stressdaten", message: "Für die Stressberechnung braucht HealthFam Herzfrequenzmessungen der Apple Watch über den Tag.")
                }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("Stress")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showBreathing) { BreathingView() }
    }
}

struct ExplanationCard: View {
    var text: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("So funktioniert's", systemImage: "info.circle").font(.subheadline.weight(.semibold))
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
    }
}
