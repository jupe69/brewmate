import SwiftUI

/// The main package list view showing packages based on selected section
struct PackageListView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @State private var isRefreshing = false
    @State private var showUninstallConfirmation = false
    @State private var showBulkOperationsPaywall = false

    /// Pagination state for large lists
    @State private var visibleItemCount: Int = 50
    private let pageSize: Int = 50

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .search:
                EmptyView() // Handled by SearchView
            case .formulae, .casks, .installed:
                packagesList
            case .updates:
                updatesView
            case .favorites, .pinned:
                packagesList // TODO: Filter by favorites/pinned
            case .taps:
                tapsView
            case .services:
                servicesView
            case .brewfile:
                brewfileView
            case .diagnostics:
                diagnosticsView
            case .cleanup:
                cleanupView
            case .quarantine:
                quarantineView
            case .history:
                historyView
            case .appStore:
                EmptyView() // Handled by MASView
            }
        }
        .navigationTitle(appState.selectedSection.rawValue)
        .searchable(text: $appState.searchText, prompt: "Search packages")
        .toolbar {
            if canShowSelectionMode {
                ToolbarItem(placement: .automatic) {
                    Button {
                        if LicenseManager.shared.isPro {
                            appState.toggleSelectionMode()
                        } else {
                            showBulkOperationsPaywall = true
                        }
                    } label: {
                        Label(
                            appState.isSelectionMode ? "Done" : "Select",
                            systemImage: appState.isSelectionMode ? "checkmark" : "checkmark.circle"
                        )
                    }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .help(LicenseManager.shared.isPro ? "Toggle selection mode (Cmd+Shift+S)" : "Pro feature: Bulk operations")
                }
            }
        }
        .sheet(isPresented: $showBulkOperationsPaywall) {
            PaywallView(feature: .bulkOperations)
        }
        .onKeyPress(.escape) {
            if appState.isSelectionMode {
                appState.clearSelection()
                appState.isSelectionMode = false
                return .handled
            }
            return .ignored
        }
        .refreshable {
            await refresh()
        }
    }

    // MARK: - Computed Properties

    private var canShowSelectionMode: Bool {
        switch appState.selectedSection {
        case .formulae, .casks, .installed, .updates, .favorites, .pinned:
            return !appState.filteredPackages.isEmpty
        default:
            return false
        }
    }

    // MARK: - Package List

    /// Visible packages with pagination applied
    private var visiblePackages: [Package] {
        let allPackages = appState.filteredPackages
        if allPackages.count <= visibleItemCount {
            return allPackages
        }
        return Array(allPackages.prefix(visibleItemCount))
    }

    private var hasMorePackages: Bool {
        appState.filteredPackages.count > visibleItemCount
    }

    private var packagesList: some View {
        Group {
            if appState.isLoading {
                SkeletonListView()
            } else if appState.filteredPackages.isEmpty {
                if appState.searchText.isEmpty {
                    EmptyStateView(
                        title: emptyTitle,
                        message: emptyMessage,
                        systemImage: emptyIcon
                    )
                } else {
                    EmptyStateView(
                        title: "No Results",
                        message: "No packages match '\(appState.searchText)'",
                        systemImage: "magnifyingglass"
                    )
                }
            } else {
                ZStack(alignment: .bottom) {
                    List(selection: $appState.selectedPackage) {
                        ForEach(visiblePackages) { package in
                            PackageRowView(
                                package: package,
                                isOutdated: isPackageOutdated(package),
                                isPinned: isPackagePinned(package),
                                isSelectionMode: appState.isSelectionMode,
                                isSelected: appState.selectedPackages.contains(package),
                                onToggleSelection: {
                                    appState.togglePackageSelection(package)
                                },
                                appState: appState
                            )
                            .tag(package)
                        }

                        // Load more trigger
                        if hasMorePackages {
                            HStack {
                                Spacer()
                                Button {
                                    loadMorePackages()
                                } label: {
                                    HStack(spacing: 8) {
                                        Text("Load more")
                                        Text("(\(appState.filteredPackages.count - visibleItemCount) remaining)")
                                            .foregroundStyle(.secondary)
                                    }
                                    .font(.subheadline)
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .listRowSeparator(.hidden)
                            .onAppear {
                                // Auto-load more when scrolling near the bottom
                                loadMorePackages()
                            }
                        }
                    }
                    .listStyle(.inset)

                    if appState.isSelectionMode && !appState.selectedPackages.isEmpty {
                        bulkActionsBar
                            .transition(.move(edge: .bottom))
                    }
                }
                .animation(.default, value: appState.isSelectionMode)
                .animation(.default, value: appState.selectedPackages.count)
            }
        }
        .onChange(of: appState.selectedSection) { _, _ in
            // Reset pagination when section changes
            visibleItemCount = pageSize
        }
        .onChange(of: appState.searchText) { _, _ in
            // Reset pagination when search changes
            visibleItemCount = pageSize
        }
    }

    private func loadMorePackages() {
        let remaining = appState.filteredPackages.count - visibleItemCount
        if remaining > 0 {
            visibleItemCount += min(pageSize, remaining)
        }
    }

    private var emptyTitle: String {
        switch appState.selectedSection {
        case .updates:
            return "You're Up to Date"
        case .favorites:
            return "No Favorites"
        case .pinned:
            return "No Pinned Packages"
        case .formulae:
            return "No Formulae"
        case .casks:
            return "No Casks"
        default:
            return "No Packages"
        }
    }

    private var emptyMessage: String {
        switch appState.selectedSection {
        case .formulae:
            return "You don't have any formulae installed."
        case .casks:
            return "You don't have any casks installed."
        case .installed:
            return "You don't have any packages installed."
        case .updates:
            return "All packages are up to date!"
        case .favorites:
            return "Mark packages as favorites to see them here."
        case .pinned:
            return "Pin packages to prevent them from being auto-upgraded."
        default:
            return "No packages to display."
        }
    }

    private var emptyIcon: String {
        switch appState.selectedSection {
        case .updates:
            return "checkmark.circle"
        case .favorites:
            return "star"
        case .pinned:
            return "pin"
        case .formulae:
            return "terminal"
        case .casks:
            return "app"
        default:
            return "shippingbox"
        }
    }

    private func isPackageOutdated(_ package: Package) -> Bool {
        appState.outdatedPackages.contains { $0.name == package.packageName }
    }

    private func isPackagePinned(_ package: Package) -> Bool {
        appState.pinnedPackages.contains(package.packageName)
    }

    // MARK: - Bulk Actions Bar

    private var bulkActionsBar: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 16) {
                Text("\(appState.selectedPackages.count) selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Install Selected") {
                    Task {
                        await installSelected()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isOperationInProgress || !hasUninstalledPackages)

                Button("Update Selected") {
                    Task {
                        await upgradeSelected()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .disabled(appState.isOperationInProgress || !hasOutdatedPackages)

                Button("Uninstall Selected") {
                    showUninstallConfirmation = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(appState.isOperationInProgress || !hasInstalledPackages)
            }
            .padding()
            .background(.bar)
        }
        .confirmationDialog(
            "Uninstall \(appState.selectedPackages.count) packages?",
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                Task {
                    await uninstallSelected()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the selected packages from your system.")
        }
    }

    private var hasInstalledPackages: Bool {
        !appState.selectedPackages.isEmpty
    }

    private var hasUninstalledPackages: Bool {
        // For search results, all are considered uninstalled
        appState.selectedSection == .search && !appState.selectedPackages.isEmpty
    }

    private var hasOutdatedPackages: Bool {
        let outdatedNames = Set(appState.outdatedPackages.map { $0.name })
        return appState.selectedPackages.contains { outdatedNames.contains($0.packageName) }
    }

    // MARK: - Updates View

    private var updatesView: some View {
        Group {
            if appState.isLoading {
                LoadingView(message: "Checking for updates...")
            } else if appState.outdatedPackages.isEmpty {
                EmptyStateView(
                    title: "All Up to Date",
                    message: "All your packages are up to date.",
                    systemImage: "checkmark.circle"
                )
            } else {
                VStack(spacing: 0) {
                    // Update all button
                    HStack {
                        Text("\(appState.outdatedPackages.count) packages have updates")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Update All") {
                            Task {
                                await upgradeAll()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appState.isOperationInProgress)
                    }
                    .padding()
                    .background(.bar)

                    Divider()

                    List(appState.outdatedPackages) { package in
                        OutdatedPackageRow(package: package, appState: appState)
                    }
                    .listStyle(.inset)
                }
            }
        }
    }

    // MARK: - Services View

    private var servicesView: some View {
        Group {
            if appState.isLoading {
                SkeletonListView(rowCount: 5)
            } else if appState.services.isEmpty {
                EmptyStateView(
                    title: "No Services",
                    message: "You don't have any Homebrew services.",
                    systemImage: "gearshape.2"
                )
            } else {
                List(appState.services) { service in
                    ServiceRowView(service: service) { action in
                        Task {
                            await controlService(service.name, action: action)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Cleanup View

    private var cleanupView: some View {
        VStack(spacing: 24) {
            Image(systemName: "trash")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Cleanup")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Remove old versions of installed formulae and casks, and clear the download cache.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            HStack(spacing: 16) {
                Button("Preview Cleanup") {
                    Task {
                        await previewCleanup()
                    }
                }
                .disabled(appState.isOperationInProgress)

                Button("Run Cleanup") {
                    Task {
                        await runCleanup()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(appState.isOperationInProgress)
            }

            if appState.isOperationInProgress {
                ProgressView()
                    .padding(.top)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Taps View

    private var tapsView: some View {
        EmptyStateView(
            title: "Taps",
            message: "Manage Homebrew repositories (taps).",
            systemImage: "plus.rectangle.on.folder"
        )
    }

    // MARK: - Brewfile View

    private var brewfileView: some View {
        BrewfileView(appState: appState)
    }

    // MARK: - Diagnostics View

    private var diagnosticsView: some View {
        DiagnosticsView(appState: appState)
    }

    // MARK: - Quarantine View

    private var quarantineView: some View {
        QuarantineView(appState: appState)
    }

    // MARK: - History View

    private var historyView: some View {
        EmptyStateView(
            title: "History",
            message: "View installation and update history.",
            systemImage: "clock"
        )
    }

    // MARK: - Actions

    private func refresh() async {
        isRefreshing = true
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

            if appState.selectedSection == .services {
                appState.services = try await brewService.getServices()
            }
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isLoading = false
        isRefreshing = false
    }

    private func upgradeAll() async {
        appState.isOperationInProgress = true
        appState.currentOperation = "Upgrading all packages..."
        appState.clearOperationOutput()

        let stream = await brewService.upgrade(packageName: nil)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false
        await refresh()
    }

    private func controlService(_ name: String, action: ServiceAction) async {
        do {
            try await brewService.controlService(name: name, action: action)
            appState.services = try await brewService.getServices()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }

    private func previewCleanup() async {
        appState.isOperationInProgress = true

        do {
            let result = try await brewService.cleanup(dryRun: true)
            // Show preview result - for now just log
            print("Would free: \(result.formattedBytesFreed)")
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }

    private func runCleanup() async {
        appState.isOperationInProgress = true

        do {
            let result = try await brewService.cleanup(dryRun: false)
            print("Freed: \(result.formattedBytesFreed)")
            await refresh()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }

    private func installSelected() async {
        let packages = Array(appState.selectedPackages)

        // Separate formulae and casks
        let casks = packages.filter { $0.isCask }.map { $0.packageName }
        let formulae = packages.filter { !$0.isCask }.map { $0.packageName }

        appState.isOperationInProgress = true
        appState.currentOperation = "Installing \(packages.count) packages..."
        appState.clearOperationOutput()

        // Install formulae first
        if !formulae.isEmpty {
            let stream = await brewService.installMultiple(packages: formulae, areCasks: false)
            for await line in stream {
                appState.appendOperationOutput(line)
            }
        }

        // Then install casks
        if !casks.isEmpty {
            let stream = await brewService.installMultiple(packages: casks, areCasks: true)
            for await line in stream {
                appState.appendOperationOutput(line)
            }
        }

        appState.isOperationInProgress = false
        appState.clearSelection()
        appState.isSelectionMode = false
        await refresh()
    }

    private func upgradeSelected() async {
        let packages = Array(appState.selectedPackages)
        let packageNames = packages.map { $0.packageName }

        appState.isOperationInProgress = true
        appState.currentOperation = "Upgrading \(packages.count) packages..."
        appState.clearOperationOutput()

        let stream = await brewService.upgradeMultiple(packages: packageNames)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false
        appState.clearSelection()
        appState.isSelectionMode = false
        await refresh()
    }

    private func uninstallSelected() async {
        let packages = Array(appState.selectedPackages)

        // Separate formulae and casks
        let casks = packages.filter { $0.isCask }.map { $0.packageName }
        let formulae = packages.filter { !$0.isCask }.map { $0.packageName }

        appState.isOperationInProgress = true
        appState.currentOperation = "Uninstalling \(packages.count) packages..."
        appState.clearOperationOutput()

        // Uninstall formulae first
        if !formulae.isEmpty {
            let stream = await brewService.uninstallMultiple(packages: formulae, areCasks: false)
            for await line in stream {
                appState.appendOperationOutput(line)
            }
        }

        // Then uninstall casks
        if !casks.isEmpty {
            let stream = await brewService.uninstallMultiple(packages: casks, areCasks: true)
            for await line in stream {
                appState.appendOperationOutput(line)
            }
        }

        appState.isOperationInProgress = false
        appState.clearSelection()
        appState.isSelectionMode = false
        await refresh()
    }

    private func uninstallSelectedPackages() async {
        let packages = appState.selectedPackages
        appState.isOperationInProgress = true
        appState.currentOperation = "Uninstalling \(packages.count) packages..."
        appState.clearOperationOutput()

        for package in packages {
            do {
                try await brewService.uninstall(packageName: package.packageName, isCask: package.isCask)
                appState.appendOperationOutput("Uninstalled \(package.packageName)")
            } catch {
                appState.appendOperationOutput("Error uninstalling \(package.packageName): \(error.localizedDescription)")
            }
        }

        appState.isOperationInProgress = false
        appState.clearSelection()
        appState.isSelectionMode = false
        await refresh()
    }
}

#Preview {
    let state = AppState()
    state.installedFormulae = [
        Formula(name: "git", fullName: "git", version: "2.43.0", description: "Distributed revision control system", homepage: nil, installedAsDependency: false, dependencies: [], installedOn: nil),
        Formula(name: "node", fullName: "node", version: "21.5.0", description: "JavaScript runtime", homepage: nil, installedAsDependency: false, dependencies: [], installedOn: nil)
    ]

    return NavigationStack {
        PackageListView(appState: state)
    }
    .frame(width: 400, height: 500)
}
