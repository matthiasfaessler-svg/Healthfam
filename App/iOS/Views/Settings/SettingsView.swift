import SwiftUI
import HealthFamCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var connectivity: PhoneConnectivity
    @State private var authMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil") {
                    TextField("Name", text: $settings.profile.name)
                    Stepper("Alter: \(settings.profile.age)", value: $settings.profile.age, in: 14...100)
                    Picker("Geschlecht", selection: Binding(
                        get: { settings.profile.sex },
                        set: { settings.profile.sex = $0; settings.sexEditedManually = true }
                    )) {
                        ForEach(BiologicalSex.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        Text("Maximalpuls")
                        Spacer()
                        Text("\(Int(settings.profile.maxHeartRate)) bpm").foregroundStyle(.secondary)
                    }
                    Toggle("Maximalpuls manuell", isOn: Binding(
                        get: { settings.profile.maxHeartRateOverride != nil },
                        set: { settings.profile.maxHeartRateOverride = $0 ? settings.profile.maxHeartRate : nil }
                    ))
                    if settings.profile.maxHeartRateOverride != nil {
                        Stepper(
                            "Max: \(Int(settings.profile.maxHeartRateOverride ?? 0)) bpm",
                            value: Binding(
                                get: { settings.profile.maxHeartRateOverride ?? 190 },
                                set: { settings.profile.maxHeartRateOverride = $0 }
                            ),
                            in: 140...230
                        )
                    }
                }

                Section("Ziele") {
                    Stepper("Schlafziel: \(Formatters.number(settings.profile.sleepGoalHours, decimals: 1)) h", value: $settings.profile.sleepGoalHours, in: 5...11, step: 0.5)
                    Stepper("Kalorien: \(Int(settings.profile.calorieGoal)) kcal", value: $settings.profile.calorieGoal, in: 1200...5000, step: 50)
                    Stepper("Protein: \(Int(settings.profile.proteinGoal)) g", value: $settings.profile.proteinGoal, in: 40...300, step: 5)
                }

                Section {
                    statusRow("Apple Health", connected: HealthKitService.shared.isAvailable && !settings.useDemoData, symbol: "heart.fill")
                    statusRow("Apple Watch gekoppelt", connected: connectivity.isPaired, symbol: "applewatch")
                    statusRow("HealthFam auf der Watch", connected: connectivity.isWatchAppInstalled, symbol: "apps.iphone")
                    Button("Health-Zugriff erneut anfragen") {
                        Task {
                            do {
                                try await HealthKitService.shared.requestAuthorization()
                                settings.useDemoData = false
                                authMessage = "Zugriff aktualisiert."
                                await dataStore.refresh()
                            } catch {
                                authMessage = error.localizedDescription
                            }
                        }
                    }
                    if let authMessage {
                        Text(authMessage).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Verbindungen")
                } footer: {
                    Text("Einzelne Datentypen kannst du jederzeit in der Health-App unter Teilen › Apps › HealthFam freigeben oder entziehen.")
                }

                Section("Daten") {
                    Toggle("Demo-Daten verwenden", isOn: Binding(
                        get: { settings.useDemoData },
                        set: { settings.useDemoData = $0; Task { await dataStore.refresh() } }
                    ))
                    Button("Jetzt aktualisieren") { Task { await dataStore.refresh() } }
                }

                Section {
                    Text("HealthFam ersetzt keine medizinische Beratung. Alle Daten werden ausschließlich auf deinem Gerät verarbeitet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        dismiss()
                        Task { await dataStore.refresh() }
                    }
                }
            }
        }
    }

    private func statusRow(_ title: String, connected: Bool, symbol: String) -> some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Image(systemName: connected ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(connected ? Theme.recovery : .secondary)
        }
    }
}
