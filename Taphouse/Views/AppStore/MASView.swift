import SwiftUI

/// View for managing Mac App Store apps via mas CLI
struct MASView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @Environment(\.openURL) private var openURL

    @State private var isLoading = false
    @State private var selectedApp: MASApp?
    @State private var searchText = ""
    @State private var searchResults: [MASSearchResult] = []
    @State private var isSearching = false
    @State private var showSearch = false

    enum Tab: String, CaseIterable {
        case installed = "Installed"
        case outdated = "Updates"
        case search = "Search"
    }

    @State private var selectedTab: Tab = .installed

    var body: some View {
        Group {
            if LicenseManager.shared.isPro {
                masContent
            } else {
                InlinePaywallView(feature: .appStore)
            }
        }
    }

    private var masContent: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            TabView(selection: $selectedTab) {
                installedList
                    .tag(Tab.installed)
                    .tabItem { Label("Installed", systemImage: "checkmark.circle") }

                outdatedList
                    .tag(Tab.outdated)
                    .tabItem {
                        Label {
                            Text("Updates")
                        } icon: {
                            Image(systemName: "arrow.up.circle")
                        }
                    }

                searchView
                    .tag(Tab.search)
                    .tabItem { Label("Search", systemImage: "magnifyingglass") }
            }
        }
        .navigationTitle("App Store")
        .overlay(alignment: .top) {
            IconLoadingBanner()
                .padding(.top, 8)
        }
        .task {
            await loadMASApps()
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Mac App Store")
                .font(.headline)

            Spacer()

            if appState.outdatedMASCount > 0 {
                Button {
                    Task { await upgradeAllMAS() }
                } label: {
                    Label("Upgrade All (\(appState.outdatedMASCount))", systemImage: "arrow.up.circle.fill")
                }
                .disabled(isLoading || appState.isOperationInProgress)
            }

            Button {
                Task { await loadMASApps() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
            .disabled(isLoading || appState.isLoading)
        }
        .padding(12)
    }

    private var installedList: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading apps...")
            } else if appState.masApps.isEmpty {
                EmptyStateView(
                    title: "No App Store Apps",
                    message: "You don't have any Mac App Store apps installed, or mas is not installed.",
                    systemImage: "bag"
                )
            } else {
                List(selection: $selectedApp) {
                    ForEach(appState.masApps) { app in
                        MASAppRow(app: app, onUninstall: {
                            Task { await uninstallMASApp(id: app.id, name: app.name) }
                        })
                            .tag(app)
                            .contextMenu {
                                Button {
                                    if let url = app.appStoreURL {
                                        openURL(url)
                                    }
                                } label: {
                                    Label("View in App Store", systemImage: "bag")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    Task { await uninstallMASApp(id: app.id, name: app.name) }
                                } label: {
                                    Label("Uninstall...", systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var outdatedList: some View {
        Group {
            if isLoading {
                LoadingView(message: "Checking for updates...")
            } else if appState.outdatedMASApps.isEmpty {
                EmptyStateView(
                    title: "All Apps Up to Date",
                    message: "All your Mac App Store apps are up to date.",
                    systemImage: "checkmark.circle"
                )
            } else {
                List {
                    ForEach(appState.outdatedMASApps) { app in
                        OutdatedMASAppRow(app: app) {
                            Task { await installMASApp(id: app.id) }
                        }
                        .contextMenu {
                            Button {
                                if let url = app.appStoreURL {
                                    openURL(url)
                                }
                            } label: {
                                Label("View in App Store", systemImage: "bag")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var searchView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search App Store...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await searchMAS() }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if isSearching {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(10)
            .background(.quaternary)

            Divider()

            if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                EmptyStateView(
                    title: "No Results",
                    message: "No apps found for '\(searchText)'",
                    systemImage: "magnifyingglass"
                )
            } else if searchResults.isEmpty {
                EmptyStateView(
                    title: "Search the App Store",
                    message: "Enter a search term to find apps",
                    systemImage: "bag"
                )
            } else {
                List {
                    ForEach(searchResults) { result in
                        MASSearchResultRow(result: result) {
                            Task { await installMASApp(id: result.id) }
                        }
                        .contextMenu {
                            Button {
                                if let url = result.appStoreURL {
                                    openURL(url)
                                }
                            } label: {
                                Label("View in App Store", systemImage: "bag")
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    // MARK: - Actions

    private func loadMASApps() async {
        isLoading = true

        do {
            async let apps = brewService.getInstalledMASApps()
            async let outdated = brewService.getOutdatedMASApps()

            appState.masApps = try await apps
            appState.outdatedMASApps = try await outdated
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isLoading = false
    }

    private func searchMAS() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true

        do {
            searchResults = try await brewService.searchMAS(query: searchText)
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isSearching = false
    }

    private func installMASApp(id: Int) async {
        appState.currentOperation = "Installing App Store app..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.installMASApp(id: id) {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false

        // Refresh the list
        await loadMASApps()
    }

    private func upgradeAllMAS() async {
        appState.currentOperation = "Upgrading App Store apps..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.upgradeMASApps() {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false

        // Refresh the list
        await loadMASApps()
    }

    private func uninstallMASApp(id: Int, name: String) async {
        appState.currentOperation = "Uninstalling \(name)..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.uninstallMASApp(id: id) {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false

        // Refresh the list
        await loadMASApps()
    }
}

// MARK: - Row Views

struct MASAppRow: View {
    let app: MASApp
    var onUninstall: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            MASAppIconView(appId: String(app.id), appName: app.name, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("v\(app.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("ID: \(app.id)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if isHovering, let onUninstall {
                Button(role: .destructive) {
                    onUninstall()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Uninstall (requires admin)")
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct OutdatedMASAppRow: View {
    let app: OutdatedMASApp
    let onUpgrade: () -> Void
    @State private var isUpgrading = false

    var body: some View {
        HStack(spacing: 12) {
            MASAppIconView(appId: String(app.id), appName: app.name, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(app.installedVersion)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(app.availableVersion)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                isUpgrading = true
                onUpgrade()
            } label: {
                if isUpgrading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Update")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isUpgrading)
        }
        .padding(.vertical, 4)
    }
}

struct MASSearchResultRow: View {
    let result: MASSearchResult
    let onInstall: () -> Void
    @State private var isInstalling = false

    var body: some View {
        HStack(spacing: 12) {
            MASAppIconView(appId: String(result.id), appName: result.name, size: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .fontWeight(.medium)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text("v\(result.version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let price = result.price, !result.isFree {
                        Text(price)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    } else {
                        Text("Free")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Spacer()

            Button {
                isInstalling = true
                onInstall()
            } label: {
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Install")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isInstalling)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    MASView(appState: AppState())
}
