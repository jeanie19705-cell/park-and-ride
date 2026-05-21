import UserNotifications

struct NotificationService {
    static func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    static func fire(facilityId: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "park_alert_\(facilityId)",
            content: content,
            trigger: nil    // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}