import SwiftUI
import HealthFamCore

@main
struct HealthFamApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var connectivity: PhoneConnectivity
    @StateObject private var dataStore: HealthDataStore
    @StateObject private var journal = JournalStore()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let settings = AppSettings()
        let connectivity = PhoneConnectivity()
        _settings = StateObject(wrappedValue: settings)
        _connectivity = StateObject(wrappedValue: connectivity)
        _dataStore = StateObject(wrappedValue: HealthDataStore(settings: settings, connectivity: connectivity))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasCompletedOnboarding {
                    RootView()
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(settings)
            .environmentObject(connectivity)
            .environmentObject(dataStore)
            .environmentObject(journal)
            .preferredColorScheme(.dark)
            .tint(Theme.recovery)
            .task {
                connectivity.onWorkoutFinished = { [weak dataStore] in
                    Task { await dataStore?.refresh() }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, settings.hasCompletedOnboarding {
                Task { await dataStore.refresh() }
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Heute", systemImage: "circle.circle") }
            TrendsView()
                .tabItem { Label("Trends", systemImage: "chart.xyaxis.line") }
            TrainingView()
                .tabItem { Label("Training", systemImage: "figure.run") }
            NutritionView()
                .tabItem { Label("Ernährung", systemImage: "fork.knife") }
            JournalView()
                .tabItem { Label("Journal", systemImage: "book.closed") }
        }
        .task {
            dataStore.startBackgroundUpdates()
            await dataStore.refresh()
        }
    }
}
