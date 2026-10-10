import SwiftUI
import HealthFamCore

struct Card<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct SectionHeader: View {
    var title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.title3.weight(.bold))
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(Theme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }
}

struct MetricTile: View {
    var title: String
    var value: String
    var unit: String = ""
    var symbol: String
    var color: Color
    var caption: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(color)
                Text(title).foregroundStyle(Theme.secondaryText)
            }
            .font(.footnote.weight(.semibold))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.title2.weight(.bold).monospacedDigit())
                if !unit.isEmpty {
                    Text(unit).font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondaryText)
                }
            }
            if let caption {
                Text(caption).font(.caption).foregroundStyle(Theme.secondaryText).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct ContributorRow: View {
    var contributor: ScoreContributor

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(contributor.name).font(.subheadline.weight(.semibold))
                if let baseline = contributor.baseline {
                    Text(baseline).font(.caption).foregroundStyle(Theme.secondaryText)
                }
            }
            Spacer()
            Text(contributor.value).font(.subheadline.monospacedDigit())
            ImpactBar(impact: contributor.impact)
                .frame(width: 56, height: 6)
        }
        .padding(.vertical, 6)
    }
}

struct ImpactBar: View {
    var impact: Double

    var body: some View {
        GeometryReader { proxy in
            let half = proxy.size.width / 2
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Theme.impactColor(impact))
                    .frame(width: max(4, half * abs(impact)))
                    .offset(x: impact >= 0 ? half : half - half * abs(impact))
            }
        }
    }
}

struct InsightCard: View {
    var insight: Insight

    private var color: Color {
        switch insight.kind {
        case .positive: return Theme.recovery
        case .neutral: return Theme.sleep
        case .warning: return Theme.strain
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.symbolName)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).font(.subheadline.weight(.bold))
                Text(insight.message).font(.subheadline).foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.largeTitle).foregroundStyle(Theme.secondaryText)
            Text(title).font(.headline)
            Text(message).font(.subheadline).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
        }
        .padding(30)
        .frame(maxWidth: .infinity)
    }
}

extension Date {
    var shortWeekday: String { formatted(.dateTime.weekday(.abbreviated)) }
    var dayNumber: String { formatted(.dateTime.day()) }
    var longDate: String { formatted(.dateTime.weekday(.wide).day().month(.wide)) }
    var timeString: String { formatted(date: .omitted, time: .shortened) }
}
