import SwiftUI
import HealthFamCore

enum Theme {
    static let recovery = Color(red: 0.20, green: 0.84, blue: 0.55)
    static let strain = Color(red: 1.00, green: 0.55, blue: 0.20)
    static let sleep = Color(red: 0.45, green: 0.45, blue: 1.00)
    static let stress = Color(red: 0.95, green: 0.35, blue: 0.45)
    static let energy = Color(red: 1.00, green: 0.82, blue: 0.25)
    static let nutrition = Color(red: 0.30, green: 0.75, blue: 0.95)
    static let heart = Color(red: 1.00, green: 0.30, blue: 0.35)

    static let background = Color.black
    static let card = Color(white: 0.11)
    static let cardSecondary = Color(white: 0.16)
    static let secondaryText = Color(white: 0.62)

    static func recoveryColor(_ score: Int?) -> Color {
        guard let score else { return .gray }
        switch score {
        case ..<34: return Color(red: 1.0, green: 0.30, blue: 0.30)
        case 34..<67: return Color(red: 1.0, green: 0.80, blue: 0.20)
        default: return recovery
        }
    }

    static func stageColor(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return Color(red: 1.0, green: 0.45, blue: 0.40)
        case .rem: return Color(red: 0.40, green: 0.80, blue: 1.0)
        case .core: return Color(red: 0.35, green: 0.50, blue: 1.0)
        case .deep: return Color(red: 0.35, green: 0.25, blue: 0.85)
        case .unspecified, .inBed: return Color(white: 0.4)
        }
    }

    static func impactColor(_ impact: Double) -> Color {
        if impact > 0.15 { return recovery }
        if impact < -0.15 { return Color(red: 1.0, green: 0.35, blue: 0.35) }
        return Color(white: 0.6)
    }
}

/// Kreisförmige Score-Anzeige im Stil von Bevel.
struct ScoreRing: View {
    var progress: Double
    var color: Color
    var lineWidth: CGFloat = 10
    var target: ClosedRange<Double>? = nil

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            if let target {
                Circle()
                    .trim(from: target.lowerBound, to: target.upperBound)
                    .stroke(color.opacity(0.35), style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(
                    AngularGradient(colors: [color.opacity(0.6), color], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.01))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.8), value: progress)
        }
    }
}

struct LabeledScoreRing: View {
    var title: String
    var value: Int?
    var color: Color
    var size: CGFloat = 96
    var lineWidth: CGFloat = 9
    var suffix: String = "%"
    var target: StrainTarget? = nil

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                ScoreRing(
                    progress: Double(value ?? 0) / 100,
                    color: color,
                    lineWidth: lineWidth,
                    target: target.map { Double($0.lower) / 100...Double($0.upper) / 100 }
                )
                VStack(spacing: 0) {
                    Text(value.map { "\($0)" } ?? "–")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    if value != nil {
                        Text(suffix)
                            .font(.system(size: size * 0.12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: size, height: size)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
    }
}
