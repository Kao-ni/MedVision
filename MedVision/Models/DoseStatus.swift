import SwiftUI

enum DoseStatus: String, CaseIterable, Identifiable, Codable {
    case pending
    case complete
    case omitted
    case missed

    var id: Self { self }

    var displayName: String {
        switch self {
        case .pending:  return "Upcoming"
        case .complete: return "Taken"
        case .omitted:  return "Skipped"
        case .missed:   return "Missed"
        }
    }

    var systemImage: String {
        switch self {
        case .pending:  return "clock"
        case .complete: return "checkmark.circle.fill"
        case .omitted:  return "xmark.circle.fill"
        case .missed:   return "exclamationmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .pending:  return .secondary
        case .complete: return .green
        case .omitted:  return .orange
        case .missed:   return .red
        }
    }
}
