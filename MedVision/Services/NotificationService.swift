import UserNotifications
import Foundation

/// Schedules and cancels local dose-reminder notifications.
/// Uses medicine.notificationTag as a stable prefix so all notifications
/// for a given medicine can be found and replaced as a group.
@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    func setup() {
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    // MARK: - Scheduling

    func schedule(for medicine: Medicine) async {
        let center = UNUserNotificationCenter.current()

        // Remove any existing notifications for this medicine first.
        let pending = await center.pendingNotificationRequests()
        let stale = pending
            .filter { $0.identifier.hasPrefix(medicine.notificationTag) }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard !medicine.scheduledTimes.isEmpty else { return }

        let content = UNMutableNotificationContent()
        content.title = medicine.name
        content.body = medicine.dosage.isEmpty
            ? "Time to take your medicine."
            : "Time to take \(medicine.dosage)."
        if !medicine.frequencyNote.isEmpty {
            content.subtitle = medicine.frequencyNote
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let calendar = Calendar.current
        for time in medicine.scheduledTimes {
            let comps = calendar.dateComponents([.hour, .minute], from: time)
            guard let hour = comps.hour, let minute = comps.minute else { continue }

            var trigger = DateComponents()
            trigger.hour = hour
            trigger.minute = minute

            let id = "\(medicine.notificationTag)-\(hour)-\(minute)"
            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: trigger, repeats: true)
            )
            try? await center.add(request)
        }
    }

    func cancel(for medicine: Medicine) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { $0.identifier.hasPrefix(medicine.notificationTag) }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Delegate

    // Show notification banner even when the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
