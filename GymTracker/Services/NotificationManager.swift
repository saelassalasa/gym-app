import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let enabledKey = "notifications_enabled"
    private let reminderHourKey = "notification_reminder_hour"

    var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if newValue {
                scheduleReminders()
            } else {
                cancelAll()
            }
        }
    }

    var reminderHour: Int {
        get {
            let h = UserDefaults.standard.integer(forKey: reminderHourKey)
            return h > 0 ? h : 9
        }
        set {
            UserDefaults.standard.set(newValue, forKey: reminderHourKey)
            if isEnabled { scheduleReminders() }
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleReminders() {
        cancelAll()
        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "IRONTRACK"
        content.body = "Time to train. Your muscles are ready."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reminder", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
