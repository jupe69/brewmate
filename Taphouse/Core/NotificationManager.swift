import Foundation
import UserNotifications
import AppKit

/// Manages local notifications for Taphouse
@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Published Properties
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Notification Center
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Notification Identifiers
    private enum NotificationIdentifier {
        static let updatesAvailable = "com.taphouse.updates.available"
        static let autoUpgradeComplete = "com.taphouse.autoupgrade.complete"
    }

    // MARK: - Notification Categories
    private enum NotificationCategory {
        static let updates = "UPDATES_CATEGORY"
        static let autoUpgrade = "AUTO_UPGRADE_CATEGORY"
    }

    // MARK: - Notification Actions
    private enum NotificationAction {
        static let openApp = "OPEN_APP_ACTION"
        static let viewUpdates = "VIEW_UPDATES_ACTION"
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        notificationCenter.delegate = self
        setupNotificationCategories()
        checkAuthorizationStatus()
    }

    // MARK: - Authorization
    func requestAuthorization() async {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await checkAuthorizationStatus()

            if granted {
                print("Notification authorization granted")
            } else {
                print("Notification authorization denied")
            }
        } catch {
            print("Failed to request notification authorization: \(error)")
        }
    }

    private func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            authorizationStatus = settings.authorizationStatus
        }
    }

    // MARK: - Notification Categories Setup
    private func setupNotificationCategories() {
        // Actions
        let openAction = UNNotificationAction(
            identifier: NotificationAction.openApp,
            title: "Open Taphouse",
            options: [.foreground]
        )

        let viewUpdatesAction = UNNotificationAction(
            identifier: NotificationAction.viewUpdates,
            title: "View Updates",
            options: [.foreground]
        )

        // Categories
        let updatesCategory = UNNotificationCategory(
            identifier: NotificationCategory.updates,
            actions: [viewUpdatesAction, openAction],
            intentIdentifiers: [],
            options: []
        )

        let autoUpgradeCategory = UNNotificationCategory(
            identifier: NotificationCategory.autoUpgrade,
            actions: [openAction],
            intentIdentifiers: [],
            options: []
        )

        notificationCenter.setNotificationCategories([updatesCategory, autoUpgradeCategory])
    }

    // MARK: - Send Notifications
    func notifyUpdatesAvailable(count: Int) async {
        guard authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Updates Available"
        content.body = "\(count) package\(count == 1 ? "" : "s") \(count == 1 ? "has" : "have") updates available"
        content.sound = .default
        content.categoryIdentifier = NotificationCategory.updates

        // Badge count
        content.badge = NSNumber(value: count)

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.updatesAvailable,
            content: content,
            trigger: nil // Deliver immediately
        )

        do {
            try await notificationCenter.add(request)
            print("Update notification sent: \(count) packages")
        } catch {
            print("Failed to send update notification: \(error)")
        }
    }

    func notifyAutoUpgradeComplete(upgraded: Int, failed: Int) async {
        guard authorizationStatus == .authorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "Auto-Upgrade Complete"

        if failed == 0 {
            content.body = "\(upgraded) package\(upgraded == 1 ? "" : "s") \(upgraded == 1 ? "was" : "were") updated successfully"
        } else {
            content.body = "\(upgraded) upgraded, \(failed) failed"
        }

        content.sound = .default
        content.categoryIdentifier = NotificationCategory.autoUpgrade

        let request = UNNotificationRequest(
            identifier: NotificationIdentifier.autoUpgradeComplete,
            content: content,
            trigger: nil
        )

        do {
            try await notificationCenter.add(request)
            print("Auto-upgrade notification sent: \(upgraded) upgraded, \(failed) failed")
        } catch {
            print("Failed to send auto-upgrade notification: \(error)")
        }
    }

    // MARK: - Clear Notifications
    func clearAllNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
        NSApp.dockTile.badgeLabel = nil
    }

    func clearBadge() {
        NSApp.dockTile.badgeLabel = nil
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Called when a notification is delivered while the app is in the foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Called when the user interacts with a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier

        Task { @MainActor in
            handleNotificationAction(actionIdentifier: actionIdentifier, notificationIdentifier: notificationIdentifier)
            completionHandler()
        }
    }

    private func handleNotificationAction(actionIdentifier: String, notificationIdentifier: String) {
        switch actionIdentifier {
        case NotificationAction.viewUpdates:
            // Switch to updates section
            NotificationCenter.default.post(
                name: .switchToSection,
                object: nil,
                userInfo: ["section": "updates"]
            )
            activateApp()

        case NotificationAction.openApp, UNNotificationDefaultActionIdentifier:
            // Just activate the app
            activateApp()

        default:
            break
        }
    }

    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)

        // Bring all windows to front
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }
}

// MARK: - Additional Notification Names

extension Notification.Name {
    static let switchToSection = Notification.Name("switchToSection")
}
