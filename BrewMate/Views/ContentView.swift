import SwiftUI

/// The main content view with 3-column navigation
struct ContentView: View {
    @State private var appState = AppState()
    @State private var brewService = BrewService()
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var hasCheckedBrew = false

    var body: some View {
        Group {
            if !hasCheckedBrew {
                LoadingView(message: "Checking Homebrew installation...")
            } else if !appState.isBrewInstalled {
                BrewNotInstalledView()
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
            case .search:
                SearchView(appState: appState)
            case .taps:
                TapsView(appState: appState)
            case .brewfile:
                BrewfileView(appState: appState)
            case .diagnostics:
                DiagnosticsView(appState: appState)
            case .history:
                HistoryView(appState: appState)
            default:
                PackageListView(appState: appState)
            }
        } detail: {
            let showsDetailPane = ![.search, .taps, .brewfile, .diagnostics, .history].contains(appState.selectedSection)

            if showsDetailPane {
                if let package = appState.selectedPackage {
                    PackageDetailView(package: package, appState: appState)
                } else {
                    noSelectionView
                }
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

        do {
            async let formulae = brewService.getInstalledFormulae()
            async let casks = brewService.getInstalledCasks()
            async let outdated = brewService.getOutdated()
            async let pinned = brewService.getPinnedPackages()

            appState.installedFormulae = try await formulae
            appState.installedCasks = try await casks
            appState.outdatedPackages = try await outdated
            appState.pinnedPackages = Set(try await pinned)

            // Notify menu bar of updates
            NotificationCenter.default.post(
                name: .packagesDidUpdate,
                object: nil,
                userInfo: ["outdatedPackages": appState.outdatedPackages]
            )
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isLoading = false
    }

    private func refresh() async {
        guard appState.isBrewInstalled else { return }

        appState.isRefreshing = true

        do {
            async let formulae = brewService.getInstalledFormulae()
            async let casks = brewService.getInstalledCasks()
            async let outdated = brewService.getOutdated()
            async let pinned = brewService.getPinnedPackages()

            appState.installedFormulae = try await formulae
            appState.installedCasks = try await casks
            appState.outdatedPackages = try await outdated
            appState.pinnedPackages = Set(try await pinned)

            if appState.selectedSection == .services {
                appState.services = try await brewService.getServices()
            }

            if appState.selectedSection == .taps {
                appState.taps = try await brewService.getTaps()
            }

            // Notify menu bar of updates
            NotificationCenter.default.post(
                name: .packagesDidUpdate,
                object: nil,
                userInfo: ["outdatedPackages": appState.outdatedPackages]
            )
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isRefreshing = false
    }

    private func refreshIfNeeded() async {
        // Only refresh if it's been a while since last refresh
        // For now, just skip to avoid too frequent refreshes
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
