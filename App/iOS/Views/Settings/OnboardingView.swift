import SwiftUI
import HealthFamCore

struct OnboardingView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var dataStore: HealthDataStore
    @State private var page = 0
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            TabView(selection: $page) {
                welcome.tag(0)
                features.tag(1)
                connect.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
        }
    }

    private var welcome: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                ScoreRing(progress: 0.82, color: Theme.recovery, lineWidth: 14).frame(width: 170, height: 170)
                ScoreRing(progress: 0.6, color: Theme.strain, lineWidth: 14).frame(width: 128, height: 128)
                ScoreRing(progress: 0.9, color: Theme.sleep, lineWidth: 14).frame(width: 86, height: 86)
            }
            VStack(spacing: 10) {
                Text("HealthFam").font(.largeTitle.weight(.heavy))
                Text("Erholung, Belastung und Schlaf –\nverständlich auf einen Blick.")
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
            }
            Spacer()
            primaryButton("Los geht's") { withAnimation { page = 1 } }
        }
        .padding(24)
        .padding(.bottom, 30)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            Text("Was HealthFam für dich tut").font(.title.weight(.bold))
            feature("heart.text.square", Theme.recovery, "Recovery", "Aus HRV, Ruhepuls, Atmung und Schlaf – verglichen mit deinen persönlichen Normalwerten.")
            feature("flame", Theme.strain, "Strain", "Misst deine Herz-Kreislauf-Belastung über den Tag und empfiehlt ein Tagesziel.")
            feature("moon.stars", Theme.sleep, "Schlaf", "Schlafphasen, Effizienz, Regelmäßigkeit und dein individueller Schlafbedarf.")
            feature("waveform.path.ecg", Theme.stress, "Stress & Energie", "Stündlicher Stressverlauf und wie viel Energie dir heute noch bleibt.")
            feature("book.closed", Theme.energy, "Journal", "Finde heraus, welche Gewohnheiten deine Erholung wirklich beeinflussen.")
            Spacer()
            primaryButton("Weiter") { withAnimation { page = 2 } }
        }
        .padding(24)
        .padding(.bottom, 30)
    }

    private var connect: some View {
        VStack(spacing: 24) {
            Spacer()
            HStack(spacing: 18) {
                Image(systemName: "applewatch").font(.system(size: 54))
                Image(systemName: "arrow.left.arrow.right").font(.title2).foregroundStyle(Theme.secondaryText)
                Image(systemName: "heart.fill").font(.system(size: 54)).foregroundStyle(Theme.heart)
            }
            Text("Apple Health & Apple Watch verbinden").font(.title2.weight(.bold)).multilineTextAlignment(.center)
            Text("HealthFam liest Herzfrequenz, HRV, Schlaf, Trainings und mehr aus Apple Health. Deine Apple Watch liefert diese Daten automatisch. Alles bleibt auf deinem Gerät.")
                .font(.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(Theme.stress).multilineTextAlignment(.center)
            }
            Spacer()
            primaryButton(isConnecting ? "Verbinde…" : "Mit Apple Health verbinden") {
                Task { await connectHealth() }
            }
            .disabled(isConnecting)

            Button("Erst mit Demo-Daten ausprobieren") {
                settings.useDemoData = true
                settings.hasCompletedOnboarding = true
                Task { await dataStore.refresh() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.secondaryText)
        }
        .padding(24)
        .padding(.bottom, 30)
    }

    private func connectHealth() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await HealthKitService.shared.requestAuthorization()
            settings.useDemoData = false
            settings.hasCompletedOnboarding = true
            await dataStore.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func feature(_ symbol: String, _ color: Color, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.recovery, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}
