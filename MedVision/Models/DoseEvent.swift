import SwiftData
import Foundation

@Model
class DoseEvent {
    var scheduledTime: Date
    var takenTime: Date?        // nil until the user acts on the dose
    var status: DoseStatus
    var medicine: Medicine?

    init(scheduledTime: Date, status: DoseStatus = .missed, medicine: Medicine? = nil) {
        self.scheduledTime = scheduledTime
        self.status = status
        self.medicine = medicine
    }
}
