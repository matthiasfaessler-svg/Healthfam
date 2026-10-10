import SwiftUI
import Charts

struct TrendPoint: Identifiable, Hashable {
    var date: Date
    var value: Double
    var id: Date { date }
}

/// Wiederverwendbares Verlaufsdiagramm mit optionaler Baseline.
struct TrendChart: View {
    enum Style { case line, bar }

    var points: [TrendPoint]
    var color: Color
    var style: Style = .line
    var baseline: Double? = nil
    var yDomain: ClosedRange<Double>? = nil
    var height: CGFloat = 180

    var body: some View {
        Chart {
            if let baseline {
                RuleMark(y: .value("Baseline", baseline))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            ForEach(points) { point in
                switch style {
                case .line:
                    AreaMark(x: .value("Tag", point.date, unit: .day), y: .value("Wert", point.value))
                        .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Tag", point.date, unit: .day), y: .value("Wert", point.value))
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.catmullRom)
                case .bar:
                    BarMark(x: .value("Tag", point.date, unit: .day), y: .value("Wert", point.value))
                        .foregroundStyle(color.gradient)
                        .cornerRadius(4)
                }
            }
        }
        .chartYScale(domain: yDomain ?? autoDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { _ in
                AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                AxisValueLabel()
            }
        }
        .frame(height: height)
    }

    private var autoDomain: ClosedRange<Double> {
        let values = points.map(\.value) + (baseline.map { [$0] } ?? [])
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        if style == .bar { return 0...max(high * 1.1, 1) }
        let pad = max((high - low) * 0.2, 1)
        return (low - pad)...(high + pad)
    }
}
