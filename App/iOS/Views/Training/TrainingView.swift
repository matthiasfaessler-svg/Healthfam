import SwiftUI
import Charts
import HealthFamCore

struct TrainingView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var settings: AppSettings

    private struct WorkoutItem: Identifiable {
        var workout: WorkoutSummary
        var analysis: DailyAnalysis
        var id: UUID { workout.id }
    }

    private var recentWorkouts: [WorkoutItem] {
        dataStore.recent(30).reversed().flatMap { analysis in
            analysis.metrics.workouts.map { WorkoutItem(workout: $0, analysis: analysis) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let today = dataStore.today {
                        StrainTargetCard(analysis: today)
                    }

                    TrainingLoadCard(days: dataStore.recent(28))

                    SectionHeader(title: "Letzte Trainings", subtitle: "Aufgezeichnet mit Apple Watch oder anderen Apps")
                    if recentWorkouts.isEmpty {
                        EmptyStateView(symbol: "figure.run", title: "Noch keine Trainings", message: "Starte ein Training in der HealthFam-App auf deiner Apple Watch oder in der Trainings-App.")
                    } else {
                        ForEach(recentWorkouts) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.analysis.day.longDate).font(.caption).foregroundStyle(Theme.secondaryText)
                                WorkoutRow(workout: item.workout, strain: HealthAnalyzer.workoutStrain(
                                    item.workout,
                                    samples: item.analysis.metrics.heartRateSamples,
                                    restingHeartRate: item.analysis.metrics.restingHeartRate ?? 60,
                                    profile: settings.profile
                                ))
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Training")
        }
    }
}

struct StrainTargetCard: View {
    var analysis: DailyAnalysis

    var body: some View {
        Card {
            HStack(spacing: 18) {
                LabeledScoreRing(title: "Strain", value: analysis.strain.score, color: Theme.strain, size: 90, target: analysis.strainTarget)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Heutiges Ziel").font(.caption.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                    Text(analysis.strainTarget.description).font(.title2.weight(.bold))
                    Text(status).font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
            }
        }
    }

    private var status: String {
        let s = analysis.strain.score
        if s < analysis.strainTarget.lower { return "Noch \(analysis.strainTarget.lower - s) % bis zum Zielbereich." }
        if s <= analysis.strainTarget.upper { return "Du bist im optimalen Bereich." }
        return "Über dem Ziel – Zeit für Erholung."
    }
}

/// Akute (7 Tage) vs. chronische (28 Tage) Belastung – zeigt Über- oder Unterforderung.
struct TrainingLoadCard: View {
    var days: [DailyAnalysis]

    var body: some View {
        let acute = Stats.mean(days.suffix(7).map { Double($0.strain.score) }) ?? 0
        let chronic = Stats.mean(days.map { Double($0.strain.score) }) ?? 0
        let ratio = chronic > 0 ? acute / chronic : 0

        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Trainingslast").font(.headline)
                    Spacer()
                    Text(label(ratio)).font(.subheadline.weight(.semibold)).foregroundStyle(color(ratio))
                }
                HStack(spacing: 20) {
                    VStack(alignment: .leading) {
                        Text("Akut (7 T)").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("\(Int(acute.rounded())) %").font(.title3.weight(.bold))
                    }
                    VStack(alignment: .leading) {
                        Text("Chronisch (28 T)").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text("\(Int(chronic.rounded())) %").font(.title3.weight(.bold))
                    }
                    VStack(alignment: .leading) {
                        Text("Verhältnis").font(.caption).foregroundStyle(Theme.secondaryText)
                        Text(Formatters.number(ratio, decimals: 2)).font(.title3.weight(.bold))
                    }
                }
                Chart(days) { day in
                    BarMark(x: .value("Tag", day.day, unit: .day), y: .value("Strain", day.strain.score))
                        .foregroundStyle(Theme.strain.gradient)
                        .cornerRadius(3)
                }
                .chartYScale(domain: 0...100)
                .frame(height: 120)
            }
        }
    }

    private func label(_ ratio: Double) -> String {
        switch ratio {
        case 0: return "–"
        case ..<0.8: return "Unterfordert"
        case 0.8...1.3: return "Optimal"
        default: return "Überlastungsrisiko"
        }
    }

    private func color(_ ratio: Double) -> Color {
        switch ratio {
        case 0.8...1.3: return Theme.recovery
        case ..<0.8: return Theme.sleep
        default: return Theme.stress
        }
    }
}
