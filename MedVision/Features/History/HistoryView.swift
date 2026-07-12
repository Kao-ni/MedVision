import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \DoseEvent.scheduledTime, order: .reverse) private var events: [DoseEvent]

    @State private var filter: DoseStatus? = nil

    private var filtered: [DoseEvent] {
        let base = events.filter { $0.status != .pending }
        guard let filter else { return base }
        return base.filter { $0.status == filter }
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
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Doses you take, skip, or miss will appear here.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("History")
        }
    }

    private var list: some View {
        List {
            Section {
                filterPicker
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            ForEach(sections, id: \.day) { section in
                Section(section.day.formatted(date: .complete, time: .omitted)) {
                    ForEach(section.events) { event in
                        DoseEventRow(event: event)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $filter) {
            Text("All").tag(DoseStatus?.none)
            ForEach(DoseStatus.allCases.filter { $0 != .pending }) { status in
                Text(status.displayName).tag(DoseStatus?.some(status))
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Filter history by outcome")
    }
}

#Preview {
    HistoryView()
        .modelContainer(PlaceholderData.previewContainer)
}
