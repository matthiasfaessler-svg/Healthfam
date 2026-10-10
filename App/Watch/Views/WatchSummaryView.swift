import SwiftUI
import HealthFamCore

struct WatchSummaryView: View {
    @EnvironmentObject private var dataModel: WatchDataModel
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        let summary = dataModel.summary
        VStack(spacing: 6) {
            ZStack {
                ScoreRing(progress: Double(summary?.recovery ?? 0) / 100, color: Theme.recoveryColor(summary?.recovery), lineWidth: 9)
                    .frame(width: 110, height: 110)
                ScoreRing(
                    progress: Double(summary?.strain ?? 0) / 100,
                    color: Theme.strain,
                    lineWidth: 9,
                    target: summary.map { Double($0.target.lower) / 100...Double($0.target.upper) / 100 }
                )
                .frame(width: 82, height: 82)
                ScoreRing(progress: Double(summary?.sleep ?? 0) / 100, color: Theme.sleep, lineWidth: 9)
                    .frame(width: 54, height: 54)
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                value("REC", summary?.recovery, Theme.recoveryColor(summary?.recovery))
                value("STR", summary?.strain, Theme.strain)
                value("SLP", summary?.sleep, Theme.sleep)
            }
        }
        .navigationTitle("HealthFam")
        .overlay {
            if summary == nil {
                if dataModel.isLoading {
                    ProgressView()
                } else {
                    Text("Öffne HealthFam auf dem iPhone").font(.footnote).multilineTextAlignment(.center)
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func value(_ label: String, _ value: Int?, _ color: Color) -> some View {
        VStack(spacing: 0) {
            Text(value.map { "\($0)" } ?? "–").font(.system(.title3, design: .rounded).weight(.bold))
            Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WatchVitalsView: View {
    @EnvironmentObject private var dataModel: WatchDataModel
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        let summary = dataModel.summary
        List {
            row("Energie", summary?.energy.map { "\($0) %" }, "battery.75percent", Theme.energy)
            row("Stress", summary?.stress.map { "\($0)" }, "waveform.path.ecg", Theme.stress)
            row("HRV", summary?.hrv.map { "\(Int($0.rounded())) ms" }, "waveform.path", Theme.recovery)
            row("Ruhepuls", summary?.restingHeartRate.map { "\(Int($0.rounded())) bpm" }, "heart.fill", Theme.heart)
            row("Schlaf", summary?.sleepDuration.map { Formatters.duration($0) }, "moon.fill", Theme.sleep)
            if let target = summary?.target {
                row("Strain-Ziel", target.description, "target", Theme.strain)
            }
        }
        .navigationTitle("Heute")
    }

    private func row(_ title: String, _ value: String?, _ symbol: String, _ color: Color) -> some View {
        HStack {
            Image(systemName: symbol).foregroundStyle(color).frame(width: 22)
            Text(title).font(.footnote)
            Spacer()
            Text(value ?? "–").font(.footnote.weight(.semibold).monospacedDigit())
        }
    }
}
