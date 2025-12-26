import SwiftUI

/// The main content view with 3-column navigation
struct ContentView: View {
    @State private var appState = AppState()
    @State private var brewService = BrewService()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasCheckedBrew = false
    @State private var lastRefreshTime: Date?

    @AppStorage("refreshOnActivate") private var refreshOnActivate = true

    // Trial notification state
    @State private var showTrialStartedAlert = false
    @State private var showTrialExpiredAlert = false
    @AppStorage("hasShownTrialStartedMessage") private var hasShownTrialStartedMessage = false
    @AppStorage("hasShownTrialExpiredMessage") private var hasShownTrialExpiredMessage = false

    var body: some View {
        Group {
            if !hasCheckedBrew {
                LoadingView(message: "Checking Homebrew installation...")
            } else if !appState.isBrewInstalled {
                OnboardingView {
                    // Re-check installation after onboarding completes
                    Task {
                        hasCheckedBrew = false
                        await checkBrewInstallation()
                        if appState.isBrewInstalled {
                            await loadInitialData()
                        }
                    }
                }
            } else {
                mainContent
            }
        }
        .task {
            await checkBrewInstallation()
        }
        .environment(\.brewService, brewService)
    }

    private var mainContent: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(appState: appState)
        } content: {
            switch appState.selectedSection {
            case .discover:
                DiscoverView(appState: appState)
            case .search:
                SearchView(appState: appState)
            case .taps:
                TapsView(appState: appState)
            case .brewfile:
                BrewfileView(appState: appState)
            case .diagnostics:
                DiagnosticsView(appState: appState)
            case .cleanup:
                CleanupView(appState: appState)
            case .quarantine:
                QuarantineView(appState: appState)
            case .history:
                HistoryView(appState: appState)
            case .appStore:
                MASView(appState: appState)
            case .services:
                ServicesView(appState: appState)
            default:
                PackageListView(appState: appState)
            }
        } detail: {
            let showsDetailPane = ![.discover, .search, .taps, .brewfile, .diagnostics, .cleanup, .quarantine, .history, .appStore, .services].contains(appState.selectedSection)

            if showsDetailPane {
                if let package = appState.selectedPackage {
                    PackageDetailView(package: package, appState: appState)
                } else {
                    noSelectionView
                }
            } else {
                // Empty view for sections without detail pane
                Color.clear
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                toolbarButtons
            }
        }
        .task {
            await loadInitialData()
        }
        .refreshable {
            await refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willBecomeActiveNotification)) { _ in
            // Refresh when app becomes active
            Task {
                await refreshIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .upgradeAllPackages)) { _ in
            Task {
                await upgradeAllPackages()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .upgradePackage)) { notification in
            if let packageName = notification.userInfo?["packageName"] as? String {
                Task {
                    await upgradePackage(packageName)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .updatesChecked)) { notification in
            // Update UI when background check finds updates
            if let outdated = notification.object as? [OutdatedPackage] {
                appState.outdatedPackages = outdated
                NotificationCenter.default.post(
                    name: .packagesDidUpdate,
                    object: nil,
                    userInfo: ["outdatedPackages": outdated]
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .autoUpgradeCompleted)) { _ in
            // Refresh package list after auto-upgrade completes
            Task {
                await refresh()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToSection)) { notification in
            // Handle notification action to switch to specific section
            if let sectionName = notification.userInfo?["section"] as? String,
               sectionName == "updates" {
                appState.selectedSection = .updates
            }
        }
        .alert("Error", isPresented: $appState.showError, presenting: appState.error) { _ in
            Button("OK") {
                appState.clearError()
            }
        } message: { error in
            Text(error.localizedDescription)
        }
        .sheet(isPresented: .init(
            get: { appState.currentOperation != nil },
            set: { if !$0 {
                appState.currentOperation = nil
                appState.clearOperationOutput()
            }}
        )) {
            OperationOutputView(
                title: appState.currentOperation ?? "Running...",
                output: appState.operationOutput,
                isRunning: appState.isOperationInProgress
            ) {
                appState.currentOperation = nil
                appState.clearOperationOutput()
            }
            .frame(minWidth: 600, minHeight: 400)
        }
        .onAppear {
            checkTrialNotifications()
        }
        .alert("Welcome to Taphouse Pro Trial", isPresented: $showTrialStartedAlert) {
            Button("Start Trial") {
                hasShownTrialStartedMessage = true
            }
        } message: {
            Text("You have 14 days to try all Pro features for free.\n\nIf you find Taphouse useful, please consider purchasing Pro. Your support helps fund continued development and new features.\n\nThank you for trying Taphouse!")
        }
        .alert("Your Trial Has Ended", isPresented: $showTrialExpiredAlert) {
            Button("Continue with Free Version") {
                hasShownTrialExpiredMessage = true
            }
            Button("Upgrade to Pro") {
                hasShownTrialExpiredMessage = true
                NSWorkspace.shared.open(LicenseManager.purchaseURL)
            }
            .keyboardShortcut(.defaultAction)
        } message: {
            Text("Your 14-day Pro trial has ended. You can continue using all free features.\n\nUpgrading to Pro ($4.99, one-time) unlocks all features and directly supports the ongoing development of Taphouse.\n\nThank you for trying Taphouse!")
        }
    }

    /// Checks if we need to show trial-related notifications
    private func checkTrialNotifications() {
        let licenseManager = LicenseManager.shared

        // Don't show anything if user has a license
        guard licenseManager.licenseInfo == nil else { return }

        // Show trial started message (first run)
        if licenseManager.isTrialActive && !hasShownTrialStartedMessage {
            showTrialStartedAlert = true
            return
        }

        // Show trial expired message
        if licenseManager.licenseStatus == .expired && !hasShownTrialExpiredMessage {
            showTrialExpiredAlert = true
            return
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Select a package")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Choose a package from the list to view its details")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var toolbarButtons: some View {
        Button {
            Task {
                await refresh()
            }
        } label: {
            Label("Refresh", systemImage: "arrow.clockwise")
        }
        .keyboardShortcut("r", modifiers: .command)
        .disabled(appState.isLoading)
        .help("Refresh (⌘R)")

        Divider()

        Button {
            Task {
                await updateBrewData()
            }
        } label: {
            Label("Update Homebrew", systemImage: "arrow.down.circle")
        }
        .disabled(appState.isLoading)
        .help("Update Homebrew package data")
    }

    // MARK: - Data Loading

    private func checkBrewInstallation() async {
        let pathResolver = BrewPathResolver()
        appState.brewPath = await pathResolver.resolve()
        appState.brewVersion = await pathResolver.getBrewVersion()
        hasCheckedBrew = true
    }

    private func loadInitialData() async {
        guard appState.isBrewInstalled else { return }

        appState.isLoading = true

        // Check if mas CLI is installed
        appState.isMASInstalled = await brewService.isMASInstalled()

        // Try to load from cache first for faster startup
        let cache = PackageCache.shared
        if let cachedFormulae = await cache.getCachedFormulae(),
           let cachedCasks = await cache.getCachedCasks() {
            appState.installedFormulae = cachedFormulae
            appState.installedCasks = cachedCasks

            // Load outdated from cache too if available
            if let cachedOutdated = await cache.getCachedOutdated() {
                appState.outdatedPackages = cachedOutdated
            }

            appState.isLoading = false

            // Refresh in background to get latest data
            Task {
                await refreshFromSource(updateCache: true)
            }
        } else {
            // No cache, load from source
            await refreshFromSource(updateCache: true)
            appState.isLoading = false
        }
    }

    private func refreshFromSource(updateCache: Bool) async {
        do {
            async let formulae = brewService.getInstalledFormulae()
            async let casks = brewService.getInstalledCasks()
            async let outdated = brewService.getOutdated()
            async let pinned = brewService.getPinnedPackages()
            async let leaves = brewService.getLeafPackages()

            let loadedFormulae = try await formulae
            let loadedCasks = try await casks
            let loadedOutdated = try await outdated

            appState.installedFormulae = loadedFormulae
            appState.installedCasks = loadedCasks
            appState.outdatedPackages = loadedOutdated
            appState.pinnedPackages = Set(try await pinned)
            appState.leafPackages = try await leaves

            // Update cache
            if updateCache {
                let cache = PackageCache.shared
                await cache.cacheFormulae(loadedFormulae)
                await cache.cacheCasks(loadedCasks)
                await cache.cacheOutdated(loadedOutdated)
            }

            // Notify menu bar of updates
            NotificationCenter.default.post(
                name: .packagesDidUpdate,
                object: nil,
                userInfo: ["outdatedPackages": appState.outdatedPackages]
            )

            // Update widget data
            WidgetDataManager.shared.updateWidgetData(outdatedPackages: appState.outdatedPackages)
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }

    private func refresh() async {
        guard appState.isBrewInstalled else { return }

        appState.isRefreshing = true

        // Re-check if mas CLI is installed (in case user just installed it)
        appState.isMASInstalled = await brewService.isMASInstalled()

        // Invalidate cache and refresh from source
        await PackageCache.shared.invalidateAll()
        await refreshFromSource(updateCache: true)

        do {
            if appState.selectedSection == .services {
                appState.services = try await brewService.getServices()
            }

            if appState.selectedSection == .taps {
                appState.taps = try await brewService.getTaps()
            }
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isRefreshing = false
    }

    private func refreshIfNeeded() async {
        guard refreshOnActivate else { return }

        // Only refresh if it's been more than 5 minutes since last refresh
        if let lastRefresh = lastRefreshTime {
            let elapsed = Date().timeIntervalSince(lastRefresh)
            guard elapsed > 300 else { return } // 5 minutes
        }

        lastRefreshTime = Date()
        await refresh()
    }

    private func updateBrewData() async {
        appState.isLoading = true
        appState.currentOperation = "Updating Homebrew..."

        do {
            try await brewService.updateBrewData()
            await refresh()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isLoading = false
        appState.currentOperation = nil
    }

    private func upgradeAllPackages() async {
        guard !appState.outdatedPackages.isEmpty else { return }

        appState.currentOperation = "Upgrading all packages..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.upgrade(packageName: nil) {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false

        // Refresh to get updated package list
        await refresh()
    }

    private func upgradePackage(_ packageName: String) async {
        appState.currentOperation = "Upgrading \(packageName)..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.upgrade(packageName: packageName) {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false

        // Refresh to get updated package list
        await refresh()
    }
}

// MARK: - Keyboard Shortcuts

extension ContentView {
    func setupKeyboardShortcuts() {
        // Cmd+F to focus search is handled by .searchable
        // Cmd+R to refresh is handled by the toolbar button
    }
}

#Preview {
    ContentView()
}
