import SwiftUI
import HealthFamCore

struct JournalView: View {
    @EnvironmentObject private var journal: JournalStore
    @EnvironmentObject private var dataStore: HealthDataStore
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var note = ""
    @State private var showBreathing = false

    private var entry: JournalEntry { journal.entry(for: day) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Button { shiftDay(-1) } label: { Image(systemName: "chevron.left") }
                        Spacer()
                        Text(Calendar.current.isDateInToday(day) ? "Heute" : day.longDate).font(.headline)
                        Spacer()
                        Button { shiftDay(1) } label: { Image(systemName: "chevron.right") }
                            .disabled(Calendar.current.isDateInToday(day))
                    }
                    .padding(.horizontal, 4)

                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Wie fühlst du dich?").font(.headline)
                            HStack {
                                ForEach(1...5, id: \.self) { mood in
                                    Button {
                                        var updated = entry
                                        updated.mood = mood
                                        journal.save(updated)
                                    } label: {
                                        Text(["😫", "😕", "😐", "🙂", "🤩"][mood - 1])
                                            .font(.largeTitle)
                                            .opacity(entry.mood == mood ? 1 : 0.35)
                                            .scaleEffect(entry.mood == mood ? 1.15 : 1)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                    }

                    ForEach(JournalTag.Category.allCases, id: \.self) { category in
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(category.displayName).font(.headline)
                                FlowLayout(spacing: 8) {
                                    ForEach(JournalTag.defaults.filter { $0.category == category }) { tag in
                                        TagChip(tag: tag, isOn: entry.tagIDs.contains(tag.id)) {
                                            journal.toggle(tag: tag.id, on: day)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notiz").font(.headline)
                            TextField("Wie war dein Tag?", text: $note, axis: .vertical)
                                .lineLimit(3...6)
                                .onSubmit(saveNote)
                            Button("Notiz sichern", action: saveNote)
                                .font(.subheadline.weight(.semibold))
                                .disabled(note == entry.note)
                        }
                    }

                    Button { showBreathing = true } label: {
                        Label("Atemübung (Achtsamkeit)", systemImage: "wind")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.nutrition.opacity(0.2), in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)

                    JournalInsightsSection()
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Journal")
            .onAppear { note = entry.note }
            .onChange(of: day) { _, _ in note = entry.note }
            .fullScreenCover(isPresented: $showBreathing) { BreathingView() }
        }
    }

    private func shiftDay(_ offset: Int) {
        guard let next = Calendar.current.date(byAdding: .day, value: offset, to: day),
              next <= Date() else { return }
        day = next
    }

    private func saveNote() {
        var updated = entry
        updated.note = note
        journal.save(updated)
    }
}

struct TagChip: View {
    var tag: JournalTag
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(tag.name, systemImage: tag.symbolName)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isOn ? Theme.recovery.opacity(0.25) : Theme.cardSecondary, in: Capsule())
                .overlay(Capsule().stroke(isOn ? Theme.recovery : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

/// Zeigt, welche Gewohnheiten die Recovery am Folgetag beeinflussen.
struct JournalInsightsSection: View {
    @EnvironmentObject private var journal: JournalStore
    @EnvironmentObject private var dataStore: HealthDataStore

    var body: some View {
        let impacts = JournalAnalyzer.impacts(entries: journal.entries, recoveryByDay: dataStore.recoveryByDay)
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Deine Erkenntnisse", subtitle: "Einfluss auf die Recovery am nächsten Tag")
            if impacts.isEmpty {
                Card {
                    Text("Erfasse mindestens drei Mal eine Gewohnheit (und drei Tage ohne), dann zeigt HealthFam dir hier ihren Einfluss.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryText)
                }
            } else {
                ForEach(impacts) { impact in
                    if let tag = JournalStore.tag(impact.tagID) {
                        HStack {
                            Image(systemName: tag.symbolName).frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(tag.name).font(.subheadline.weight(.semibold))
                                Text("\(impact.occurrences)× erfasst").font(.caption).foregroundStyle(Theme.secondaryText)
                            }
                            Spacer()
                            Text(String(format: "%+.0f %%", impact.delta))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(impact.delta >= 0 ? Theme.recovery : Theme.stress)
                        }
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}

/// Einfaches Fließlayout für Tag-Chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            width = max(width, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
