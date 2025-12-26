import SwiftUI
import AppKit

/// Manages the menu bar icon and menu for Taphouse
@MainActor
@Observable
final class MenuBarManager {
    private var statusItem: NSStatusItem?
    private let brewService: BrewService
    private var updateTimer: Timer?

    var outdatedPackages: [OutdatedPackage] = []
    var services: [BrewServiceInfo] = []
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
            button.image = NSImage(systemSymbolName: "mug.fill", accessibilityDescription: "Taphouse")
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

        // Services section
        if !services.isEmpty {
            menu.addItem(NSMenuItem.separator())

            let servicesMenu = NSMenu()
            let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
            servicesItem.submenu = servicesMenu

            // Group services by status
            let runningServices = services.filter { $0.status.isActive }
            let stoppedServices = services.filter { !$0.status.isActive }

            // Running services
            if !runningServices.isEmpty {
                let runningHeader = NSMenuItem(title: "Running (\(runningServices.count))", action: nil, keyEquivalent: "")
                runningHeader.isEnabled = false
                servicesMenu.addItem(runningHeader)

                for service in runningServices.prefix(10) {
                    let serviceSubmenu = NSMenu()

                    let stopItem = NSMenuItem(title: "Stop", action: #selector(stopService(_:)), keyEquivalent: "")
                    stopItem.target = self
                    stopItem.representedObject = service.name
                    stopItem.image = NSImage(systemSymbolName: "stop.fill", accessibilityDescription: nil)
                    serviceSubmenu.addItem(stopItem)

                    let restartItem = NSMenuItem(title: "Restart", action: #selector(restartService(_:)), keyEquivalent: "")
                    restartItem.target = self
                    restartItem.representedObject = service.name
                    restartItem.image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: nil)
                    serviceSubmenu.addItem(restartItem)

                    let serviceItem = NSMenuItem(title: service.name, action: nil, keyEquivalent: "")
                    serviceItem.submenu = serviceSubmenu
                    serviceItem.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)
                    serviceItem.image?.isTemplate = false
                    // Tint the circle green for running
                    servicesMenu.addItem(serviceItem)
                }
            }

            // Stopped services
            if !stoppedServices.isEmpty {
                if !runningServices.isEmpty {
                    servicesMenu.addItem(NSMenuItem.separator())
                }

                let stoppedHeader = NSMenuItem(title: "Stopped (\(stoppedServices.count))", action: nil, keyEquivalent: "")
                stoppedHeader.isEnabled = false
                servicesMenu.addItem(stoppedHeader)

                for service in stoppedServices.prefix(10) {
                    let startItem = NSMenuItem(title: service.name, action: #selector(startService(_:)), keyEquivalent: "")
                    startItem.target = self
                    startItem.representedObject = service.name
                    startItem.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)
                    servicesMenu.addItem(startItem)
                }
            }

            menu.addItem(servicesItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Open Taphouse
        let openItem = NSMenuItem(title: "Open Taphouse", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Taphouse", action: #selector(quitApp), keyEquivalent: "q")
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

    @objc private func startService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        Task {
            do {
                try await brewService.controlService(name: serviceName, action: .start)
                await refreshServices()
            } catch {
                print("Failed to start service: \(error)")
            }
        }
    }

    @objc private func stopService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        Task {
            do {
                try await brewService.controlService(name: serviceName, action: .stop)
                await refreshServices()
            } catch {
                print("Failed to stop service: \(error)")
            }
        }
    }

    @objc private func restartService(_ sender: NSMenuItem) {
        guard let serviceName = sender.representedObject as? String else { return }
        Task {
            do {
                try await brewService.controlService(name: serviceName, action: .restart)
                await refreshServices()
            } catch {
                print("Failed to restart service: \(error)")
            }
        }
    }

    @objc private func openMainWindow() {
        // If in menu bar only mode, switch back to regular mode to show dock icon
        let menuBarOnlyMode = UserDefaults.standard.bool(forKey: "menuBarOnlyMode")
        if menuBarOnlyMode {
            NSApp.setActivationPolicy(.regular)
        }

        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Find the main content window and show it
        var foundWindow = false
        for window in NSApp.windows {
            // Skip status bar windows, panels, and other system windows
            let className = window.className
            if className.contains("StatusBar") ||
               className.contains("Panel") ||
               className.contains("TUINS") ||
               window.level == .statusBar {
                continue
            }

            // Show and focus the window
            window.makeKeyAndOrderFront(nil)
            foundWindow = true
            break  // Only need to show one main window
        }

        // If no suitable window found, we need to create one
        // This happens if the app was launched directly into menu bar only mode
        if !foundWindow {
            // Temporarily disable menu bar only mode to allow window creation
            if menuBarOnlyMode {
                UserDefaults.standard.set(false, forKey: "menuBarOnlyMode")
                NotificationCenter.default.post(name: .menuBarOnlyModeChanged, object: nil)
            }
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

    func refreshServices() async {
        do {
            services = try await brewService.getServices()
            updateMenu()
        } catch {
            print("Failed to get services: \(error)")
        }
    }

    func refreshAll() async {
        async let packages: () = refreshOutdatedPackages()
        async let servicesRefresh: () = refreshServices()
        _ = await (packages, servicesRefresh)
    }

    private var outdatedCount: Int {
        outdatedPackages.count
    }

    // MARK: - Periodic Updates

    private func startPeriodicUpdates() {
        // Check for updates every 30 minutes
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }

        // Do an initial check
        Task {
            await refreshAll()
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
