import SwiftUI
import AppKit

/// Manages the menu bar icon and menu for BrewMate
@MainActor
@Observable
final class MenuBarManager {
    private var statusItem: NSStatusItem?
    private let brewService: BrewService
    private var updateTimer: Timer?

    var outdatedPackages: [OutdatedPackage] = []
    var isCheckingUpdates: Bool = false
    var showMenuBarIcon: Bool {
        didSet {
            if showMenuBarIcon && LicenseManager.shared.isPro {
                setupMenuBar()
            } else {
                removeMenuBar()
            }
        }
    }

    init(brewService: BrewService, showMenuBarIcon: Bool = false) {
        self.brewService = brewService
        self.showMenuBarIcon = showMenuBarIcon

        if showMenuBarIcon && LicenseManager.shared.isPro {
            setupMenuBar()
        }
    }

    // MARK: - Setup

    private func setupMenuBar() {
        // Menu bar is a Pro feature
        guard LicenseManager.shared.isPro else {
            removeMenuBar()
            return
        }

        guard statusItem == nil else { return }

        let statusBar = NSStatusBar.system
        statusItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mug.fill", accessibilityDescription: "BrewMate")
            button.imagePosition = .imageLeft
        }

        updateMenu()
        startPeriodicUpdates()
    }

    private func removeMenuBar() {
        stopPeriodicUpdates()
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    // MARK: - Menu Updates

    func updateMenu() {
        let menu = NSMenu()

        // Status header
        let statusText = outdatedCount > 0
            ? "\(outdatedCount) update\(outdatedCount == 1 ? "" : "s") available"
            : "Up to date"

        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quick actions
        let checkUpdatesItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdates), keyEquivalent: "u")
        checkUpdatesItem.target = self
        menu.addItem(checkUpdatesItem)

        let upgradeAllItem = NSMenuItem(title: "Upgrade All", action: #selector(upgradeAll), keyEquivalent: "U")
        upgradeAllItem.target = self
        upgradeAllItem.isEnabled = outdatedCount > 0
        menu.addItem(upgradeAllItem)

        // Outdated packages section
        if !outdatedPackages.isEmpty {
            menu.addItem(NSMenuItem.separator())

            // Show up to 5 outdated packages
            for package in outdatedPackages.prefix(5) {
                let packageItem = NSMenuItem(
                    title: "\(package.name) (\(package.installedVersion) → \(package.currentVersion))",
                    action: #selector(upgradePackage(_:)),
                    keyEquivalent: ""
                )
                packageItem.target = self
                packageItem.representedObject = package.name
                packageItem.image = NSImage(systemSymbolName: package.isCask ? "app.badge" : "terminal", accessibilityDescription: nil)
                menu.addItem(packageItem)
            }

            // Show "and X more..." if there are more packages
            if outdatedPackages.count > 5 {
                let moreItem = NSMenuItem(title: "and \(outdatedPackages.count - 5) more...", action: nil, keyEquivalent: "")
                moreItem.isEnabled = false
                menu.addItem(moreItem)
            }
        }

        menu.addItem(NSMenuItem.separator())

        // Open BrewMate
        let openItem = NSMenuItem(title: "Open BrewMate", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit BrewMate", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Update button to show badge if updates available
        updateButtonAppearance()
    }

    private func updateButtonAppearance() {
        guard let button = statusItem?.button else { return }

        if outdatedCount > 0 {
            // Show badge by adding the count as a title
            button.title = " \(outdatedCount)"
        } else {
            button.title = ""
        }
    }

    // MARK: - Actions

    @objc private func checkForUpdates() {
        Task {
            isCheckingUpdates = true
            await refreshOutdatedPackages()
            isCheckingUpdates = false

            // Show notification if updates found
            if outdatedCount > 0 {
                showNotification(
                    title: "Updates Available",
                    body: "\(outdatedCount) package\(outdatedCount == 1 ? "" : "s") can be upgraded"
                )
            }
        }
    }

    @objc private func upgradeAll() {
        Task {
            openMainWindow()
            NotificationCenter.default.post(name: .upgradeAllPackages, object: nil)
        }
    }

    @objc private func upgradePackage(_ sender: NSMenuItem) {
        guard let packageName = sender.representedObject as? String else { return }

        Task {
            openMainWindow()
            NotificationCenter.default.post(
                name: .upgradePackage,
                object: nil,
                userInfo: ["packageName": packageName]
            )
        }
    }

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)

        // Bring all windows to front
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }

        // If no windows are visible, create a new one
        if NSApp.windows.isEmpty || NSApp.windows.allSatisfy({ !$0.isVisible }) {
            NotificationCenter.default.post(name: .showMainWindow, object: nil)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Data Management

    func refreshOutdatedPackages() async {
        do {
            outdatedPackages = try await brewService.getOutdated()
            updateMenu()
        } catch {
            print("Failed to get outdated packages: \(error)")
        }
    }

    private var outdatedCount: Int {
        outdatedPackages.count
    }

    // MARK: - Periodic Updates

    private func startPeriodicUpdates() {
        // Check for updates every 30 minutes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshOutdatedPackages()
            }
        }

        // Do an initial check
        Task {
            await refreshOutdatedPackages()
        }
    }

    private func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    // MARK: - Notifications

    private func showNotification(title: String, body: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = body
        notification.soundName = NSUserNotificationDefaultSoundName

        NSUserNotificationCenter.default.deliver(notification)
    }

}

// MARK: - Notification Names

extension Notification.Name {
    static let upgradeAllPackages = Notification.Name("upgradeAllPackages")
    static let upgradePackage = Notification.Name("upgradePackage")
    static let showMainWindow = Notification.Name("showMainWindow")
}
