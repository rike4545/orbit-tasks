//
//  NotificationManager.swift
//  Orbit Tasks
//
//  Local notifications helper
//  Swift 6 • iOS 17+
//

import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        guard settings.authorizationStatus == .notDetermined else { return }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            // Refresh status after request
            let newSettings = await center.notificationSettings()
            authorizationStatus = newSettings.authorizationStatus

            // If granted, nothing else to do here.
            _ = granted
        } catch {
            // Ignore failures; user can enable later in Settings
            let newSettings = await center.notificationSettings()
            authorizationStatus = newSettings.authorizationStatus
        }
    }

    func scheduleReminder(for taskID: UUID, title: String, at date: Date) async {
        let center = UNUserNotificationCenter.current()

        // If not authorized, silently no-op.
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = "Orbit reminder"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        let request = UNNotificationRequest(
            identifier: "orbit.task.\(taskID.uuidString)",
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            // Ignore scheduling errors
        }
    }

    func cancelReminder(for taskID: UUID) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["orbit.task.\(taskID.uuidString)"])
    }
}
