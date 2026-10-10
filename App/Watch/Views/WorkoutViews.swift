import SwiftUI
import HealthKit
import HealthFamCore

struct WorkoutStartView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var dataModel: WatchDataModel

    var body: some View {
        List(HKWorkoutActivityType.quickStart, id: \.rawValue) { type in
            Button {
                prepare()
                Task { await workoutManager.start(type) }
            } label: {
                Label(type.displayName, systemImage: type.symbolName)
                    .padding(.vertical, 6)
            }
        }
        .navigationTitle("Training")
        .alert("Fehler", isPresented: Binding(
            get: { workoutManager.errorMessage != nil },
            set: { if !$0 { workoutManager.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(workoutManager.errorMessage ?? "")
        }
    }

    private func prepare() {
        let summary = dataModel.summary
        workoutManager.profile = summary?.profile ?? UserProfile()
        workoutManager.restingHeartRate = summary?.restingHeartRate ?? 60
        workoutManager.strainBeforeWorkout = summary?.strain ?? 0
    }
}

struct LiveWorkoutView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        TabView {
            LiveMetricsView()
            controls
        }
        .tabViewStyle(.page)
    }

    private var controls: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                controlButton(
                    workoutManager.state == .paused ? "Weiter" : "Pause",
                    workoutManager.state == .paused ? "play.fill" : "pause.fill",
                    Theme.energy
                ) { workoutManager.togglePause() }
                controlButton("Beenden", "xmark", Theme.stress) { workoutManager.end() }
            }
            Text(workoutManager.activity.displayName).font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func controlButton(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        VStack {
            Button(action: action) {
                Image(systemName: symbol).font(.title2)
            }
            .tint(color)
            .buttonStyle(.bordered)
            .frame(width: 64, height: 50)
            Text(title).font(.caption2)
        }
    }
}

struct LiveMetricsView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatters.clock(workoutManager.elapsedTime))
                    .font(.system(.title, design: .rounded).monospacedDigit().weight(.semibold))
                    .foregroundStyle(Theme.energy)
                HStack {
                    Text("\(Int(workoutManager.heartRate))")
                        .font(.system(.title2, design: .rounded).monospacedDigit())
                    Image(systemName: "heart.fill").foregroundStyle(Theme.heart)
                    Spacer()
                    if workoutManager.zone > 0 {
                        Text("Z\(workoutManager.zone)")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 6)
                            .background(Theme.strain.opacity(0.3), in: Capsule())
                    }
                }
                Text("\(Int(workoutManager.activeEnergy)) kcal")
                    .font(.system(.title3, design: .rounded).monospacedDigit())
                if workoutManager.distance > 0 {
                    Text("\(Formatters.number(workoutManager.distance / 1000, decimals: 2)) km")
                        .font(.system(.title3, design: .rounded).monospacedDigit())
                }
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill").foregroundStyle(Theme.strain)
                    Text("Strain \(workoutManager.dayStrain) %")
                    Text("(+\(workoutManager.workoutStrain))").foregroundStyle(.secondary)
                }
                .font(.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(workoutManager.state == .paused ? 0.5 : 1)
        }
        .padding(.horizontal, 4)
    }
}

struct WorkoutSummaryView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var dataModel: WatchDataModel

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: workoutManager.activity.symbolName).font(.title).foregroundStyle(Theme.strain)
                Text("Training beendet").font(.headline)
                ZStack {
                    ScoreRing(progress: Double(workoutManager.workoutStrain) / 100, color: Theme.strain, lineWidth: 8)
                    VStack(spacing: 0) {
                        Text("\(workoutManager.workoutStrain)").font(.title2.weight(.bold))
                        Text("Strain").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)
                if let workout = workoutManager.finishedWorkout {
                    summaryRow("Dauer", Formatters.duration(workout.duration))
                }
                summaryRow("Kalorien", "\(Int(workoutManager.activeEnergy)) kcal")
                summaryRow("Ø Puls", "\(Int(workoutManager.averageHeartRate)) bpm")
                if workoutManager.distance > 0 {
                    summaryRow("Distanz", "\(Formatters.number(workoutManager.distance / 1000, decimals: 2)) km")
                }
                summaryRow("Tages-Strain", "\(workoutManager.dayStrain) %")
                Button("Fertig") {
                    workoutManager.dismissSummary()
                    Task { await dataModel.refresh() }
                }
                .padding(.top, 6)
            }
        }
    }

    private func summaryRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
        .font(.footnote)
    }
}
