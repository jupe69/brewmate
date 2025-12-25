import SwiftUI

/// Main app entry point
@main
struct TaphouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @State private var menuBarManager: MenuBarManager?

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupMenuBarManager()
                }
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) { }

            // Check for Updates in app menu
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView()
            }

            CommandMenu("Packages") {
                Button("Refresh") {
                    NotificationCenter.default.post(name: .refreshPackages, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Update Homebrew") {
                    NotificationCenter.default.post(name: .updateHomebrew, object: nil)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .help) {
                Link("Homebrew Documentation", destination: URL(string: "https://docs.brew.sh")!)

                Divider()

                Button("About Taphouse") {
                    NSApp.orderFrontStandardAboutPanel(nil)
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    @MainActor
    private func setupMenuBarManager() {
        if menuBarManager == nil {
            let brewService = BrewService()
            menuBarManager = MenuBarManager(brewService: brewService, showMenuBarIcon: showMenuBarIcon)

            // Listen for setting changes
            NotificationCenter.default.addObserver(
                forName: .menuBarIconSettingChanged,
                object: nil,
                queue: .main
            ) { [weak menuBarManager] notification in
                if let enabled = notification.userInfo?["enabled"] as? Bool {
                    menuBarManager?.showMenuBarIcon = enabled
                }
            }

            // Listen for package updates to refresh menu bar
            NotificationCenter.default.addObserver(
                forName: .packagesDidUpdate,
                object: nil,
                queue: .main
            ) { [weak menuBarManager] notification in
                if let packages = notification.userInfo?["outdatedPackages"] as? [OutdatedPackage] {
                    Task { @MainActor in
                        menuBarManager?.outdatedPackages = packages
                        menuBarManager?.updateMenu()
                    }
                }
            }
        }
        menuBarManager?.showMenuBarIcon = showMenuBarIcon
    }
}

/// App delegate for handling app lifecycle
class AppDelegate: NSObject, NSApplicationDelegate {
    private var updateScheduler: UpdateScheduler?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize license manager and start trial if needed
        LicenseManager.shared.startTrialIfNeeded()

        // Validate license in background if we have one
        Task {
            await LicenseManager.shared.validateOnStartup()
        }

        // Initialize and start the update scheduler
        Task { @MainActor in
            updateScheduler = UpdateScheduler()
            updateScheduler?.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        updateScheduler?.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit if menu bar icon is shown
        // Default to true if key doesn't exist (first launch)
        if UserDefaults.standard.object(forKey: "showMenuBarIcon") == nil {
            return false
        }
        let showMenuBarIcon = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        return !showMenuBarIcon
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let refreshPackages = Notification.Name("refreshPackages")
    static let updateHomebrew = Notification.Name("updateHomebrew")
    static let menuBarIconSettingChanged = Notification.Name("menuBarIconSettingChanged")
    static let packagesDidUpdate = Notification.Name("packagesDidUpdate")
}

// MARK: - Settings View

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            HomebrewSettingsView()
                .tabItem {
                    Label("Homebrew", systemImage: "shippingbox")
                }

            LicenseSettingsView()
                .tabItem {
                    Label("License", systemImage: "key.fill")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 550, height: 550)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("refreshOnActivate") private var refreshOnActivate = true
    @AppStorage("confirmBeforeUninstall") private var confirmBeforeUninstall = true
    @AppStorage("showDependencies") private var showDependencies = true
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true

    @StateObject private var updateScheduler = UpdateScheduler()

    private var isPro: Bool { LicenseManager.shared.isPro }

    var body: some View {
        Form {
            Section {
                Toggle("Show in menu bar", isOn: $showMenuBarIcon)
                    .disabled(!isPro)
                    .onChange(of: showMenuBarIcon) { _, newValue in
                        // Notify the app to update menu bar
                        NotificationCenter.default.post(
                            name: .menuBarIconSettingChanged,
                            object: nil,
                            userInfo: ["enabled": newValue]
                        )
                    }

                Text("Keep Taphouse accessible from the menu bar with quick actions and update notifications")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !isPro {
                    proFeatureNote
                }
            } header: {
                proSectionHeader("Menu Bar")
            }

            Section {
                Toggle("Refresh packages when app becomes active", isOn: $refreshOnActivate)
                Toggle("Confirm before uninstalling packages", isOn: $confirmBeforeUninstall)
                Toggle("Show dependencies in package details", isOn: $showDependencies)
            } header: {
                Text("Behavior")
            }

            Section {
                Toggle("Check for updates automatically", isOn: Binding(
                    get: { updateScheduler.autoCheckEnabled },
                    set: { updateScheduler.autoCheckEnabled = $0 }
                ))
                .disabled(!isPro)

                if updateScheduler.autoCheckEnabled && isPro {
                    Picker("Check frequency", selection: Binding(
                        get: { updateScheduler.checkFrequency },
                        set: { updateScheduler.checkFrequency = $0 }
                    )) {
                        ForEach(CheckFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Notify when updates are available", isOn: Binding(
                        get: { updateScheduler.notifyOnUpdates },
                        set: { updateScheduler.notifyOnUpdates = $0 }
                    ))

                    if let lastCheck = updateScheduler.lastCheckDate {
                        LabeledContent("Last checked") {
                            Text(lastCheck, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !isPro {
                    proFeatureNote
                }
            } header: {
                proSectionHeader("Update Checks")
            } footer: {
                if updateScheduler.autoCheckEnabled && isPro {
                    Text("Taphouse will check for package updates in the background at the specified interval.")
                }
            }

            Section {
                Toggle("Auto-upgrade packages", isOn: Binding(
                    get: { updateScheduler.autoUpgradeEnabled },
                    set: { updateScheduler.autoUpgradeEnabled = $0 }
                ))
                .disabled(!isPro)

                if updateScheduler.autoUpgradeEnabled && isPro {
                    Picker("Upgrade frequency", selection: Binding(
                        get: { updateScheduler.autoUpgradeFrequency },
                        set: { updateScheduler.autoUpgradeFrequency = $0 }
                    )) {
                        ForEach(CheckFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)

                    if let lastUpgrade = updateScheduler.lastAutoUpgradeDate {
                        LabeledContent("Last auto-upgrade") {
                            Text(lastUpgrade, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if !isPro {
                    proFeatureNote
                }
            } header: {
                proSectionHeader("Auto-Upgrade")
            } footer: {
                if updateScheduler.autoUpgradeEnabled && isPro {
                    Text("Packages will be automatically upgraded in the background. Pinned packages are not upgraded. Updates respect battery status and won't run on low battery (<20%).")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private func proSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
            if !isPro {
                Text("PRO")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private var proFeatureNote: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
            Text("Requires Pro")
        }
        .font(.caption)
        .foregroundStyle(.orange)
    }
}

struct HomebrewSettingsView: View {
    @State private var brewPath: String = ""
    @State private var brewVersion: String = ""
    @State private var brewPrefix: String = ""
    @State private var isLoading = true

    var body: some View {
        Form {
            Section {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    LabeledContent("Homebrew Path") {
                        Text(brewPath)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    LabeledContent("Version") {
                        Text(brewVersion)
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Prefix") {
                        Text(brewPrefix)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            } header: {
                Text("Installation")
            }

            Section {
                Link(destination: URL(string: "https://brew.sh")!) {
                    Label("Homebrew Website", systemImage: "globe")
                }
                Link(destination: URL(string: "https://docs.brew.sh")!) {
                    Label("Documentation", systemImage: "book")
                }
                Link(destination: URL(string: "https://formulae.brew.sh")!) {
                    Label("Package Search", systemImage: "magnifyingglass")
                }
            } header: {
                Text("Resources")
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            await loadBrewInfo()
        }
    }

    private func loadBrewInfo() async {
        let resolver = BrewPathResolver()
        brewPath = await resolver.resolve() ?? "Not found"
        brewVersion = await resolver.getBrewVersion() ?? "Unknown"
        brewPrefix = await resolver.getBrewPrefix() ?? "Unknown"
        isLoading = false
    }
}

struct AboutSettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "mug")
                .font(.system(size: 64))
                .foregroundStyle(.brown)

            Text("Taphouse")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(Bundle.main.appVersionString) (\(Bundle.main.buildNumberString))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("A native macOS GUI for Homebrew")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Divider()
                .frame(width: 200)

            Text("© 2025 Multimodal Solutions")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersionString: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    var buildNumberString: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
