import SwiftUI
import HealthFamCore

@main
struct HealthFamWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityManager.shared
    @StateObject private var dataModel = WatchDataModel()
    @StateObject private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(connectivity)
                .environmentObject(dataModel)
                .environmentObject(workoutManager)
                .tint(Theme.recovery)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var workoutManager: WorkoutManager
    @EnvironmentObject private var dataModel: WatchDataModel

    var body: some View {
        Group {
            switch workoutManager.state {
            case .idle:
                NavigationStack {
                    TabView {
                        WatchSummaryView()
                        WatchVitalsView()
                        WorkoutStartView()
                    }
                    .tabViewStyle(.verticalPage)
                }
            case .running, .paused:
                LiveWorkoutView()
            case .finished:
                WorkoutSummaryView()
            }
        }
        .task { await dataModel.refresh() }
    }
}
