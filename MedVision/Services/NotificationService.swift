import UserNotifications

private enum NotificationConstants {
    static let reminderCategory = "MEDICINE_REMINDER"
    static let snoozeAction = "SNOOZE_MEDICINE_10_MINUTES"
    static let snoozeSuffix = "-snooze"
    static let snoozeInterval: TimeInterval = 10 * 60
    static let migrationKey = "notification_snooze_actions_v1"
}

@MainActor
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    enum SnoozeResult: Equatable {
        case scheduled(Date)
        case notificationsDisabled
        case failed
    }

    override private init() {
        super.init()
    }

    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let snooze = UNNotificationAction(
            identifier: NotificationConstants.snoozeAction,
            title: AppLanguage.localized("Snooze 10 min"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: NotificationConstants.reminderCategory,
            actions: [snooze],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestPermission() async {
        configure()
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

        let content = notificationContent(for: medicine)

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

    /// Rewrites pre-snooze reminder requests once so upgraded installations
    /// receive the notification category and its Snooze action.
    func refreshExistingRemindersIfNeeded(medicines: [Medicine]) async {
        guard !UserDefaults.standard.bool(forKey: NotificationConstants.migrationKey) else { return }
        for medicine in medicines {
            await schedule(for: medicine)
        }
        UserDefaults.standard.set(true, forKey: NotificationConstants.migrationKey)
    }

    func snooze(_ event: DoseEvent) async -> SnoozeResult {
        guard let medicine = event.medicine else { return .failed }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard Self.canDeliverNotifications(settings.authorizationStatus) else {
            return .notificationsDisabled
        }

        let fireDate = Date().addingTimeInterval(NotificationConstants.snoozeInterval)
        let identifier = snoozeIdentifier(for: event)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let request = UNNotificationRequest(
            identifier: identifier,
            content: notificationContent(for: medicine),
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: NotificationConstants.snoozeInterval,
                repeats: false
            )
        )

        do {
            try await center.add(request)
            return .scheduled(fireDate)
        } catch {
            return .failed
        }
    }

    func cancelSnooze(for event: DoseEvent) {
        let identifier = snoozeIdentifier(for: event)
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func notificationContent(for medicine: Medicine) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = medicine.name
        content.body = medicine.dosage.isEmpty
            ? AppLanguage.localized("Time to take your medicine.")
            : AppLanguage.localized(
                "time_to_take_dosage_format",
                arguments: [medicine.dosage]
            )
        if !medicine.frequencyNote.isEmpty {
            content.subtitle = medicine.frequencyNote
        }
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = NotificationConstants.reminderCategory
        return content
    }

    private func snoozeIdentifier(for event: DoseEvent) -> String {
        guard let medicine = event.medicine else {
            return "unknown-dose\(NotificationConstants.snoozeSuffix)"
        }
        let components = Calendar.current.dateComponents(
            [.hour, .minute],
            from: event.scheduledTime
        )
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return "\(medicine.notificationTag)-\(hour)-\(minute)\(NotificationConstants.snoozeSuffix)"
    }

    private static func canDeliverNotifications(
        _ status: UNAuthorizationStatus
    ) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        case .notDetermined, .denied:
            false
        @unknown default:
            false
        }
    }

    private func snooze(notification: UNNotification) async {
        let center = UNUserNotificationCenter.current()
        let sourceIdentifier = notification.request.identifier
        let baseIdentifier = sourceIdentifier.hasSuffix(NotificationConstants.snoozeSuffix)
            ? String(sourceIdentifier.dropLast(NotificationConstants.snoozeSuffix.count))
            : sourceIdentifier
        let identifier = baseIdentifier + NotificationConstants.snoozeSuffix
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard let content = notification.request.content.mutableCopy()
                as? UNMutableNotificationContent else { return }
        content.categoryIdentifier = NotificationConstants.reminderCategory

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(
                timeInterval: NotificationConstants.snoozeInterval,
                repeats: false
            )
        )
        try? await center.add(request)
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
        Task { @MainActor in
            if response.actionIdentifier == NotificationConstants.snoozeAction {
                await self.snooze(notification: response.notification)
            }
            completionHandler()
        }
    }
}
