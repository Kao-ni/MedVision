import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \DoseEvent.scheduledTime) private var allEvents: [DoseEvent]

    private var todayEvents: [DoseEvent] {
        allEvents.filter { Calendar.current.isDateInToday($0.scheduledTime) }
    }

    private var overdue: [DoseEvent]  { todayEvents.filter { $0.status == .pending && $0.scheduledTime < .now } }
    private var upcoming: [DoseEvent] { todayEvents.filter { $0.status == .pending && $0.scheduledTime >= .now } }
    private var done: [DoseEvent]     { todayEvents.filter { $0.status != .pending }.sorted { $0.scheduledTime < $1.scheduledTime } }

    private var takenCount: Int  { todayEvents.filter { $0.status == .complete }.count }
    private var totalCount: Int  { todayEvents.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }

    var body: some View {
        NavigationStack {
            Group {
                if todayEvents.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 0) {
                        Text("Today")
                            .font(.headline)
                        Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var list: some View {
        List {
            Section {
                ProgressCard(taken: takenCount, total: totalCount, progress: progress)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if !overdue.isEmpty {
                Section {
                    ForEach(overdue) { event in
                        TodayDoseRow(event: event, isOverdue: true)
                    }
                } header: {
                    Label("Overdue", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }

            if !upcoming.isEmpty {
                Section {
                    ForEach(upcoming) { event in
                        TodayDoseRow(event: event, isOverdue: false)
                    }
                } header: {
                    Label("Upcoming — \(upcoming.count)", systemImage: "clock")
                }
            }

            if !done.isEmpty {
                Section {
                    ForEach(done) { event in
                        TodayDoseRow(event: event, isOverdue: false)
                    }
                } header: {
                    Label("Done — \(done.count)", systemImage: "checkmark.circle")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing Scheduled", systemImage: "moon.zzz")
        } description: {
            Text("Add medicines and their schedule in the Medicines tab.")
        }
    }
}

// MARK: - Progress Card

private struct ProgressCard: View {
    let taken: Int
    let total: Int
    let progress: Double

    private var allDone: Bool { taken == total }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(allDone ? "All done!" : "\(taken) of \(total) taken today")
                        .font(.headline)
                    Text(allDone ? "Great job keeping up with your medicines." : "\(total - taken) dose\(total - taken == 1 ? "" : "s") remaining")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(allDone ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.4), value: progress)
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(width: 52, height: 52)
            }

            ProgressView(value: progress)
                .tint(allDone ? .green : .blue)
                .animation(.easeOut(duration: 0.4), value: progress)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Row

struct TodayDoseRow: View {
    let event: DoseEvent
    let isOverdue: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(event.medicine?.name ?? "Unknown")
                            .font(.title3)
                            .fontWeight(.semibold)
                        if isOverdue {
                            Text("Overdue")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.15))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    if let dosage = event.medicine?.dosage, !dosage.isEmpty {
                        Text(dosage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(event.scheduledTime.formatted(date: .omitted, time: .shortened))
                    .font(.headline)
                    .monospacedDigit()
                    .foregroundStyle(isOverdue ? .red : .secondary)
            }

            if event.status == .pending {
                HStack(spacing: 10) {
                    Button { event.status = .omitted } label: {
                        Text("Skip")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)

                    Button {
                        event.status = .complete
                        event.takenTime = Date()
                    } label: {
                        Label("Take Now", systemImage: "checkmark")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isOverdue ? Color.red : Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                HStack {
                    Label(event.status.displayName, systemImage: event.status.systemImage)
                        .font(.subheadline)
                        .foregroundStyle(event.status.color)
                    if let takenTime = event.takenTime, event.status == .complete {
                        Text("at \(takenTime.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if event.status != .pending {
                Button {
                    event.status = .pending
                    event.takenTime = nil
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .tint(.indigo)
            }
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PlaceholderData.previewContainer)
}
