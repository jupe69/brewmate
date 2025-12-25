import Foundation
import Cocoa
import IOKit.ps

/// Manages background update checks and automatic upgrades for Homebrew packages
@MainActor
final class UpdateScheduler: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var isChecking = false
    @Published private(set) var lastCheckDate: Date?
    @Published private(set) var lastAutoUpgradeDate: Date?

    // MARK: - Dependencies
    private let brewService: BrewService
    private let notificationManager: NotificationManager

    // MARK: - Timer
    private var checkTimer: Timer?
    private var autoUpgradeTimer: Timer?

    // MARK: - UserDefaults Keys
    private enum DefaultsKeys {
        static let autoCheckEnabled = "autoCheckEnabled"
        static let checkFrequency = "checkFrequency"
        static let notifyOnUpdates = "notifyOnUpdates"
        static let autoUpgradeEnabled = "autoUpgradeEnabled"
        static let autoUpgradeFrequency = "autoUpgradeFrequency"
        static let lastCheckDate = "lastCheckDate"
        static let lastAutoUpgradeDate = "lastAutoUpgradeDate"
    }

    // MARK: - Settings
    var autoCheckEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKeys.autoCheckEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKeys.autoCheckEnabled)
            scheduleNextCheck()
        }
    }

    var checkFrequency: CheckFrequency {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: DefaultsKeys.checkFrequency),
               let frequency = CheckFrequency(rawValue: rawValue) {
                return frequency
            }
            return .daily
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKeys.checkFrequency)
            scheduleNextCheck()
        }
    }

    var notifyOnUpdates: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKeys.notifyOnUpdates) }
        set { UserDefaults.standard.set(newValue, forKey: DefaultsKeys.notifyOnUpdates) }
    }

    var autoUpgradeEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: DefaultsKeys.autoUpgradeEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: DefaultsKeys.autoUpgradeEnabled)
            scheduleNextAutoUpgrade()
        }
    }

    var autoUpgradeFrequency: CheckFrequency {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: DefaultsKeys.autoUpgradeFrequency),
               let frequency = CheckFrequency(rawValue: rawValue) {
                return frequency
            }
            return .weekly
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: DefaultsKeys.autoUpgradeFrequency)
            scheduleNextAutoUpgrade()
        }
    }

    // MARK: - Initialization
    init(brewService: BrewService = BrewService(), notificationManager: NotificationManager = NotificationManager.shared) {
        self.brewService = brewService
        self.notificationManager = notificationManager

        // Load last check dates
        if let lastCheck = UserDefaults.standard.object(forKey: DefaultsKeys.lastCheckDate) as? Date {
            self.lastCheckDate = lastCheck
        }
        if let lastUpgrade = UserDefaults.standard.object(forKey: DefaultsKeys.lastAutoUpgradeDate) as? Date {
            self.lastAutoUpgradeDate = lastUpgrade
        }
    }

    // MARK: - Lifecycle
    func start() {
        Task {
            await notificationManager.requestAuthorization()
        }
        scheduleNextCheck()
        scheduleNextAutoUpgrade()
    }

    func stop() {
        checkTimer?.invalidate()
        checkTimer = nil
        autoUpgradeTimer?.invalidate()
        autoUpgradeTimer = nil
    }

    // MARK: - Scheduling
    private func scheduleNextCheck() {
        checkTimer?.invalidate()
        checkTimer = nil

        guard autoCheckEnabled else { return }

        let interval = checkFrequency.timeInterval
        checkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performUpdateCheck()
            }
        }

        // Also run an initial check if it's been a while
        if shouldPerformCheck() {
            Task {
                await performUpdateCheck()
            }
        }
    }

    private func scheduleNextAutoUpgrade() {
        autoUpgradeTimer?.invalidate()
        autoUpgradeTimer = nil

        guard autoUpgradeEnabled else { return }

        let interval = autoUpgradeFrequency.timeInterval
        autoUpgradeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performAutoUpgrade()
            }
        }
    }

    // MARK: - Update Check
    private func shouldPerformCheck() -> Bool {
        guard let lastCheck = lastCheckDate else { return true }
        let elapsed = Date().timeIntervalSince(lastCheck)
        return elapsed >= checkFrequency.timeInterval
    }

    func performUpdateCheck() async {
        guard !isChecking else { return }
        guard canRunOnBattery() else {
            print("Skipping update check - device on low battery")
            return
        }

        isChecking = true
        defer { isChecking = false }

        do {
            // First update Homebrew itself
            try await brewService.updateBrewData()

            // Then check for outdated packages
            let outdated = try await brewService.getOutdated()

            lastCheckDate = Date()
            UserDefaults.standard.set(lastCheckDate, forKey: DefaultsKeys.lastCheckDate)

            // Send notification if updates are available
            if !outdated.isEmpty && notifyOnUpdates {
                await notificationManager.notifyUpdatesAvailable(count: outdated.count)
            }

            // Post notification for UI refresh
            NotificationCenter.default.post(name: .updatesChecked, object: outdated)

        } catch {
            print("Update check failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Auto Upgrade
    private func performAutoUpgrade() async {
        guard canRunOnBattery() else {
            print("Skipping auto-upgrade - device on low battery")
            return
        }

        do {
            // Get outdated packages
            let outdated = try await brewService.getOutdated()

            // Filter out pinned packages
            let upgradeable = outdated.filter { !$0.pinned }

            guard !upgradeable.isEmpty else {
                print("No packages to auto-upgrade")
                return
            }

            var upgraded = 0
            var failed = 0

            // Upgrade each package
            for package in upgradeable {
                do {
                    var output = ""
                    for await line in await brewService.upgrade(packageName: package.name) {
                        output += line
                    }

                    // Log to installation history
                    logUpgrade(package: package, output: output, success: true)
                    upgraded += 1

                } catch {
                    logUpgrade(package: package, output: error.localizedDescription, success: false)
                    failed += 1
                }
            }

            lastAutoUpgradeDate = Date()
            UserDefaults.standard.set(lastAutoUpgradeDate, forKey: DefaultsKeys.lastAutoUpgradeDate)

            // Send notification
            await notificationManager.notifyAutoUpgradeComplete(upgraded: upgraded, failed: failed)

            // Post notification for UI refresh
            NotificationCenter.default.post(name: .autoUpgradeCompleted, object: nil)

        } catch {
            print("Auto-upgrade failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    private func canRunOnBattery() -> Bool {
        // Check power source state
        let powerSourceInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let powerSources = IOPSCopyPowerSourcesList(powerSourceInfo)?.takeRetainedValue() as? [CFTypeRef]

        guard let sources = powerSources else { return true }

        for source in sources {
            if let sourceInfo = IOPSGetPowerSourceDescription(powerSourceInfo, source)?.takeUnretainedValue() as? [String: Any] {
                // Check if on battery
                if let isCharging = sourceInfo[kIOPSIsChargingKey] as? Bool,
                   let currentCapacity = sourceInfo[kIOPSCurrentCapacityKey] as? Int {
                    // Don't run on low battery (< 20%)
                    if !isCharging && currentCapacity < 20 {
                        return false
                    }
                }
            }
        }

        return true
    }

    private func logUpgrade(package: OutdatedPackage, output: String, success: Bool) {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let logEntry = """
        [\(formatter.string(from: timestamp))] Auto-upgrade: \(package.name)
        From: \(package.installedVersion) -> \(package.currentVersion)
        Status: \(success ? "SUCCESS" : "FAILED")
        Output: \(output)
        ---
        """

        // Append to log file
        if let logURL = getLogFileURL() {
            do {
                let handle = try FileHandle(forWritingTo: logURL)
                handle.seekToEndOfFile()
                if let data = logEntry.data(using: .utf8) {
                    handle.write(data)
                }
                try handle.close()
            } catch {
                // File doesn't exist, create it
                try? logEntry.write(to: logURL, atomically: true, encoding: .utf8)
            }
        }
    }

    private func getLogFileURL() -> URL? {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }

        let brewMateDir = appSupport.appendingPathComponent("BrewMate", isDirectory: true)

        // Create directory if needed
        if !FileManager.default.fileExists(atPath: brewMateDir.path) {
            try? FileManager.default.createDirectory(at: brewMateDir, withIntermediateDirectories: true)
        }

        return brewMateDir.appendingPathComponent("upgrade_history.log")
    }
}

// MARK: - Check Frequency

enum CheckFrequency: String, CaseIterable, Identifiable {
    case hourly = "Hourly"
    case daily = "Daily"
    case weekly = "Weekly"

    var id: String { rawValue }

    var timeInterval: TimeInterval {
        switch self {
        case .hourly:
            return 3600 // 1 hour
        case .daily:
            return 86400 // 24 hours
        case .weekly:
            return 604800 // 7 days
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let updatesChecked = Notification.Name("updatesChecked")
    static let autoUpgradeCompleted = Notification.Name("autoUpgradeCompleted")
}
