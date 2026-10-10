import SwiftUI
import HealthFamCore

/// Geführte Atemübung (4 s ein, 6 s aus). Wird als Achtsamkeitsminuten in Apple Health gespeichert.
struct BreathingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var inhale = false
    @State private var start = Date()
    @State private var phaseText = "Einatmen"
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 40) {
                Spacer()
                ZStack {
                    ForEach(0..<6) { i in
                        Circle()
                            .fill(Theme.nutrition.opacity(0.25))
                            .frame(width: 140, height: 140)
                            .offset(x: inhale ? 50 : 0)
                            .rotationEffect(.degrees(Double(i) * 60))
                    }
                }
                .scaleEffect(inhale ? 1.25 : 0.6)
                .rotationEffect(.degrees(inhale ? 90 : 0))
                Text(phaseText).font(.title.weight(.semibold))
                Spacer()
                TimelineView(.periodic(from: start, by: 1)) { context in
                    Text(Formatters.clock(context.date.timeIntervalSince(start)))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.secondaryText)
                }
                Button {
                    finish()
                } label: {
                    Text("Fertig")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 30)
        }
        .onAppear(perform: begin)
        .onDisappear { timer?.invalidate() }
    }

    private func begin() {
        start = Date()
        cycle()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
            Task { @MainActor in cycle() }
        }
    }

    private func cycle() {
        phaseText = "Einatmen"
        withAnimation(.easeInOut(duration: 4)) { inhale = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            phaseText = "Ausatmen"
            withAnimation(.easeInOut(duration: 6)) { inhale = false }
        }
    }

    private func finish() {
        timer?.invalidate()
        let end = Date()
        if end.timeIntervalSince(start) >= 30, !settings.useDemoData {
            let begin = start
            Task { try? await HealthKitService.shared.saveMindfulSession(start: begin, end: end) }
        }
        dismiss()
    }
}
