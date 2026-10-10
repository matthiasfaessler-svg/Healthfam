import SwiftUI
import HealthFamCore

struct TodayView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DayStrip()
                    if let analysis = dataStore.selected {
                        content(for: analysis)
                    } else if dataStore.isLoading {
                        ProgressView().padding(60)
                    } else {
                        EmptyStateView(
                            symbol: "applewatch.radiowaves.left.and.right",
                            title: "Noch keine Daten",
                            message: dataStore.lastError ?? "Trage deine Apple Watch, damit Herzfrequenz und Schlaf in Apple Health erscheinen."
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.background)
            .refreshable { await dataStore.refresh() }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "person.crop.circle").font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(for: Detail.self) { detail in
                switch detail {
                case .recovery: RecoveryDetailView()
                case .strain: StrainDetailView()
                case .sleep: SleepDetailView()
                case .stress: StressDetailView()
                }
            }
        }
    }

    enum Detail: Hashable { case recovery, strain, sleep, stress }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = settings.profile.name.isEmpty ? "" : ", \(settings.profile.name)"
        switch hour {
        case 5..<11: return "Guten Morgen\(name)"
        case 11..<18: return "Hallo\(name)"
        default: return "Guten Abend\(name)"
        }
    }

    @ViewBuilder
    private func content(for analysis: DailyAnalysis) -> some View {
        Card {
            HStack {
                NavigationLink(value: Detail.recovery) {
                    LabeledScoreRing(title: "Recovery", value: analysis.recovery?.score, color: Theme.recoveryColor(analysis.recovery?.score))
                }
                Spacer()
                NavigationLink(value: Detail.strain) {
                    LabeledScoreRing(title: "Strain", value: analysis.strain.score, color: Theme.strain, target: analysis.strainTarget)
                }
                Spacer()
                NavigationLink(value: Detail.sleep) {
                    LabeledScoreRing(title: "Schlaf", value: analysis.sleep?.score, color: Theme.sleep)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }

        if let recovery = analysis.recovery {
            Text(recovery.headline)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }

        HStack(spacing: 12) {
            EnergyCard(energy: analysis.energy)
            NavigationLink(value: Detail.stress) {
                StressCard(stress: analysis.stress)
            }
            .buttonStyle(.plain)
        }

        let insights = InsightEngine.insights(for: analysis, history: dataStore.analyses.filter { $0.day <= analysis.day })
        if !insights.isEmpty {
            SectionHeader(title: "Coach")
            ForEach(insights) { InsightCard(insight: $0) }
        }

        SectionHeader(title: "Vitalwerte", subtitle: "Verglichen mit deinem 30-Tage-Schnitt")
        VitalsGrid(analysis: analysis)

        SectionHeader(title: "Aktivität")
        ActivitySummaryCard(analysis: analysis)

        if !analysis.metrics.workouts.isEmpty {
            SectionHeader(title: "Trainings")
            ForEach(analysis.metrics.workouts) { workout in
                WorkoutRow(workout: workout, strain: HealthAnalyzer.workoutStrain(
                    workout,
                    samples: analysis.metrics.heartRateSamples,
                    restingHeartRate: analysis.metrics.restingHeartRate ?? 60,
                    profile: settings.profile
                ))
            }
        }

        if let updated = dataStore.lastUpdated {
            Text("Aktualisiert \(updated.timeString)\(settings.useDemoData ? " · Demo-Daten" : "")")
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
                .padding(.top, 8)
        }
    }
}

/// Horizontale Wochenleiste zur Tagesauswahl.
struct DayStrip: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    private var days: [Date] {
        let today = Calendar.current.startOfDay(for: Date())
        return (0..<14).reversed().compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { day in
                        let selected = Calendar.current.isDate(day, inSameDayAs: dataStore.selectedDay)
                        let recovery = dataStore.analysis(for: day)?.recovery?.score
                        Button {
                            withAnimation { dataStore.selectedDay = day }
                        } label: {
                            VStack(spacing: 6) {
                                Text(day.shortWeekday).font(.caption2.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                                Text(day.dayNumber).font(.headline)
                                Circle().fill(Theme.recoveryColor(recovery)).frame(width: 6, height: 6)
                                    .opacity(recovery == nil ? 0 : 1)
                            }
                            .frame(width: 44, height: 70)
                            .background(selected ? Theme.cardSecondary : .clear, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .id(day)
                    }
                }
            }
            .onAppear { proxy.scrollTo(days.last, anchor: .trailing) }
        }
    }
}

struct EnergyCard: View {
    var energy: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Energie", systemImage: "battery.75percent")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.energy)
            Text(energy.map { "\($0) %" } ?? "–").font(.title.weight(.bold).monospacedDigit())
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.energy.opacity(0.18))
                    Capsule().fill(Theme.energy).frame(width: proxy.size.width * Double(energy ?? 0) / 100)
                }
            }
            .frame(height: 8)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct StressCard: View {
    var stress: StressResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Stress", systemImage: "waveform.path.ecg")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.stress)
            HStack(alignment: .firstTextBaseline) {
                Text(stress.map { "\($0.average)" } ?? "–").font(.title.weight(.bold).monospacedDigit())
                Text(stress?.label ?? "").font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach((stress?.timeline ?? []).suffix(16)) { point in
                    Capsule()
                        .fill(point.isActivity ? Theme.strain : Theme.stress.opacity(0.4 + point.level / 170))
                        .frame(height: max(3, point.level / 100 * 22))
                }
            }
            .frame(height: 22, alignment: .bottom)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct VitalsGrid: View {
    var analysis: DailyAnalysis

    var body: some View {
        let m = analysis.metrics
        let b = analysis.baseline
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "HRV", value: m.hrv.map { "\(Int($0.rounded()))" } ?? "–", unit: "ms", symbol: "waveform.path", color: Theme.recovery, caption: b.hrv.map { "Ø \(Int($0.mean.rounded())) ms" })
            MetricTile(title: "Ruhepuls", value: m.restingHeartRate.map { "\(Int($0.rounded()))" } ?? "–", unit: "bpm", symbol: "heart.fill", color: Theme.heart, caption: b.restingHeartRate.map { "Ø \(Int($0.mean.rounded())) bpm" })
            MetricTile(title: "Atemfrequenz", value: m.respiratoryRate.map { Formatters.number($0, decimals: 1) } ?? "–", unit: "/min", symbol: "lungs.fill", color: Theme.nutrition, caption: b.respiratoryRate.map { "Ø \(Formatters.number($0.mean, decimals: 1))" })
            MetricTile(title: "Blutsauerstoff", value: m.oxygenSaturation.map { "\(Int(($0 * 100).rounded()))" } ?? "–", unit: "%", symbol: "drop.fill", color: Theme.stress)
            MetricTile(
                title: "Temperatur",
                value: zipTemp(m.wristTemperature, b.wristTemperature?.mean).map { String(format: "%+.1f", $0) } ?? "–",
                unit: "°C",
                symbol: "thermometer.medium",
                color: Theme.energy,
                caption: "Abweichung"
            )
            MetricTile(title: "VO₂max", value: m.vo2Max.map { Formatters.number($0, decimals: 1) } ?? "–", unit: "ml/kg·min", symbol: "figure.run.circle", color: Theme.strain)
        }
    }

    private func zipTemp(_ value: Double?, _ mean: Double?) -> Double? {
        guard let value, let mean else { return nil }
        return value - mean
    }
}

struct ActivitySummaryCard: View {
    var analysis: DailyAnalysis

    var body: some View {
        HStack(spacing: 12) {
            MetricTile(title: "Schritte", value: Formatters.number(analysis.metrics.steps), symbol: "figure.walk", color: Theme.recovery)
            MetricTile(title: "Aktiv", value: Formatters.number(analysis.metrics.activeEnergy), unit: "kcal", symbol: "flame.fill", color: Theme.strain)
        }
    }
}

struct WorkoutRow: View {
    var workout: WorkoutSummary
    var strain: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: workout.symbolName)
                .font(.title2)
                .foregroundStyle(Theme.strain)
                .frame(width: 48, height: 48)
                .background(Theme.strain.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.activityName).font(.headline)
                Text("\(workout.start.timeString) · \(Formatters.duration(workout.duration))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryText)
                HStack(spacing: 10) {
                    if let kcal = workout.activeEnergy {
                        Label("\(Int(kcal)) kcal", systemImage: "flame")
                    }
                    if let hr = workout.averageHeartRate {
                        Label("\(Int(hr)) bpm", systemImage: "heart")
                    }
                    if let distance = workout.distanceMeters, distance > 0 {
                        Label("\(Formatters.number(distance / 1000, decimals: 2)) km", systemImage: "location")
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            ZStack {
                ScoreRing(progress: Double(strain) / 100, color: Theme.strain, lineWidth: 5)
                Text("\(strain)").font(.caption.weight(.bold))
            }
            .frame(width: 40, height: 40)
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
