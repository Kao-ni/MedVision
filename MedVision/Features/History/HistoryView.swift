import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DoseEvent.scheduledTime, order: .reverse) private var events: [DoseEvent]
    @Environment(\.locale) private var locale
    @State private var filter: DoseStatus?

    private var completedEvents: [DoseEvent] {
        events.filter { $0.status != .pending }
    }

    private var filtered: [DoseEvent] {
        guard let filter else { return completedEvents }
        return completedEvents.filter { $0.status == filter }
    }

    private var sections: [(day: Date, events: [DoseEvent])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.scheduledTime) }
        return groups
            .map { (day: $0.key, events: $0.value.sorted { $0.scheduledTime > $1.scheduledTime }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    if completedEvents.isEmpty {
                        MVEmptyState(
                            systemImage: "clock.arrow.circlepath",
                            title: "No history yet",
                            message: "Doses you take, skip, or miss will appear here."
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 34)
                        .glassCard()
                    } else {
                        filterPicker

                        if sections.isEmpty {
                            MVEmptyState(
                                systemImage: "line.3.horizontal.decrease.circle",
                                title: "No results for this filter",
                                message: "Choose another status to see your dose history."
                            )
                            .frame(maxWidth: .infinity)
                            .glassCard()
                        } else {
                            ForEach(sections, id: \.day) { section in
                                historySection(section)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .mvScreenBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("History")
                .font(.system(size: 31, weight: .bold, design: .rounded))
                .foregroundStyle(Color.mvInk)
            Text("A record of your medicine routine")
                .font(.subheadline)
                .foregroundStyle(Color.mvSubtle)
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            Text("All").tag(DoseStatus?.none)
            ForEach(DoseStatus.allCases.filter { $0 != .pending }) { status in
                Text(LocalizedStringKey(status.localizationKey))
                    .tag(DoseStatus?.some(status))
            }
        }
        .pickerStyle(.segmented)
        .padding(7)
        .glassCard(cornerRadius: 16)
        .accessibilityLabel("Filter history by outcome")
    }

    private func historySection(_ section: (day: Date, events: [DoseEvent])) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(
                    section.day,
                    format: Date.FormatStyle(date: .complete, time: .omitted)
                        .locale(locale)
                )
                .font(.system(size: 13, weight: .bold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(Color.mvSubtle)
                Spacer()
                Text("\(section.events.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.mvAccent)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.events.enumerated()), id: \.element.id) { index, event in
                    DoseEventRow(event: event)
                    if index < section.events.count - 1 {
                        Divider()
                            .overlay(Color.mvBorder.opacity(0.45))
                            .padding(.leading, 62)
                    }
                }
            }
            .padding(.horizontal, 15)
            .glassCard()
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Medicine.self, DoseEvent.self], inMemory: true)
}
