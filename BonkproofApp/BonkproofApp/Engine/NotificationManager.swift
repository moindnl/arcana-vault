import UserNotifications

enum NotificationManager {

    static let preRideMealId = "bonkproof.preRideMeal"

    // MARK: - Authorization

    /// Returns true if authorized (or just became authorized).
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional: return true
        case .denied:                   return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    // MARK: - Pre-ride meal notification

    /// Schedule (or replace) a pre-ride meal reminder.
    /// Notification fires at `startTime − 3h`.
    /// Returns false if the fire date is in the past or permission denied.
    @discardableResult
    static func schedulePreRideMeal(
        startTime: Date,
        carbMin: Int,
        carbMax: Int,
        isGerman: Bool
    ) async -> Bool {
        let fireDate = startTime.addingTimeInterval(-3 * 3600)
        guard fireDate > Date.now else { return false }

        let granted = await requestAuthorization()
        guard granted else { return false }

        let content = UNMutableNotificationContent()
        if isGerman {
            content.title = "Mahlzeit vor der Fahrt 🍝"
            content.body  = "Jetzt \(carbMin)–\(carbMax) g Carbs essen — dein Start ist in 3 Stunden."
        } else {
            content.title = "Pre-Ride Meal 🍝"
            content.body  = "Eat \(carbMin)–\(carbMax) g carbs now — your ride starts in 3 hours."
        }
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: preRideMealId, content: content, trigger: trigger)

        // Remove any previous before adding
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [preRideMealId])
        try? await UNUserNotificationCenter.current().add(request)
        return true
    }

    static func cancelPreRideMeal() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [preRideMealId])
    }
}
