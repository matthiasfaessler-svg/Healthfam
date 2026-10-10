import SwiftUI
import HealthFamCore

struct NutritionView: View {
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var settings: AppSettings
    @State private var showAdd = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    let nutrition = dataStore.today?.metrics.nutrition ?? .empty
                    let burned = (dataStore.today?.metrics.activeEnergy ?? 0) + (dataStore.today?.metrics.basalEnergy ?? 0)
                    let profile = settings.profile

                    Card {
                        HStack(spacing: 20) {
                            ZStack {
                                ScoreRing(progress: nutrition.calories / max(profile.calorieGoal, 1), color: Theme.nutrition, lineWidth: 14)
                                VStack(spacing: 0) {
                                    Text(Formatters.number(nutrition.calories)).font(.title2.weight(.bold))
                                    Text("von \(Formatters.number(profile.calorieGoal)) kcal").font(.caption2).foregroundStyle(Theme.secondaryText)
                                }
                            }
                            .frame(width: 130, height: 130)
                            VStack(alignment: .leading, spacing: 10) {
                                stat("Verbrannt", "\(Formatters.number(burned)) kcal", Theme.strain)
                                stat("Bilanz", "\(Formatters.number(nutrition.calories - burned)) kcal", Theme.energy)
                                stat("Wasser", "\(Formatters.number(nutrition.water / 1000, decimals: 1)) l", Theme.nutrition)
                            }
                        }
                    }

                    Card {
                        VStack(spacing: 14) {
                            MacroBar(name: "Protein", value: nutrition.protein, goal: profile.proteinGoal, color: Theme.recovery)
                            MacroBar(name: "Kohlenhydrate", value: nutrition.carbohydrates, goal: profile.calorieGoal * 0.45 / 4, color: Theme.energy)
                            MacroBar(name: "Fett", value: nutrition.fat, goal: profile.calorieGoal * 0.3 / 9, color: Theme.strain)
                        }
                    }

                    HStack(spacing: 12) {
                        quickButton("Mahlzeit", "plus.circle.fill", Theme.nutrition) { showAdd = true }
                        quickButton("+250 ml", "drop.fill", Theme.sleep) { addWater(250) }
                        quickButton("+500 ml", "waterbottle.fill", Theme.sleep) { addWater(500) }
                    }

                    if let message {
                        Text(message).font(.footnote).foregroundStyle(Theme.secondaryText)
                    }

                    ExplanationCard(text: "HealthFam liest Ernährungsdaten aus Apple Health – egal ob du sie hier oder in Apps wie MyFitnessPal, Yazio oder Lifesum erfasst. Eine ausreichende Proteinzufuhr unterstützt die Regeneration nach dem Training.")
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Ernährung")
            .sheet(isPresented: $showAdd) {
                AddMealView { message = $0 }
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func addWater(_ ml: Double) {
        guard !settings.useDemoData else {
            message = "Im Demo-Modus wird nichts in Apple Health gespeichert."
            return
        }
        Task {
            do {
                try await HealthKitService.shared.saveWater(milliliters: ml)
                message = "\(Int(ml)) ml Wasser gespeichert."
                await dataStore.refresh()
            } catch {
                message = error.localizedDescription
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(color)
            Text(value).font(.subheadline.weight(.bold).monospacedDigit())
        }
    }

    private func quickButton(_ title: String, _ symbol: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol).font(.title2).foregroundStyle(color)
                Text(title).font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

struct MacroBar: View {
    var name: String
    var value: Double
    var goal: Double
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(value)) / \(Int(goal)) g").font(.subheadline.monospacedDigit()).foregroundStyle(Theme.secondaryText)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color).frame(width: proxy.size.width * min(value / max(goal, 1), 1))
                }
            }
            .frame(height: 8)
        }
    }
}

struct AddMealView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataStore: HealthDataStore
    @EnvironmentObject private var settings: AppSettings
    var onSaved: (String) -> Void

    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Mahlzeit") {
                    field("Kalorien", "kcal", $calories)
                    field("Protein", "g", $protein)
                    field("Kohlenhydrate", "g", $carbs)
                    field("Fett", "g", $fat)
                }
                Section {
                    Text("Wird in Apple Health gespeichert und fließt in deine Tagesbilanz ein.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Mahlzeit erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") { Task { await save() } }.disabled(isSaving || number(calories) == 0)
                }
            }
        }
    }

    private func field(_ title: String, _ unit: String, _ text: Binding<String>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func number(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func save() async {
        guard !settings.useDemoData else {
            onSaved("Im Demo-Modus wird nichts in Apple Health gespeichert.")
            dismiss()
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await HealthKitService.shared.saveNutrition(
                calories: number(calories),
                protein: number(protein),
                carbohydrates: number(carbs),
                fat: number(fat)
            )
            onSaved("Mahlzeit gespeichert.")
            dismiss()
            await dataStore.refresh()
        } catch {
            onSaved(error.localizedDescription)
            dismiss()
        }
    }
}
