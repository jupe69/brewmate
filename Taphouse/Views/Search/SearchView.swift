import SwiftUI

/// View for searching and installing new packages
struct SearchView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var searchQuery = ""
    @State private var searchResults: SearchResults?
    @State private var isSearching = false
    @State private var selectedResult: SearchResultItem?
    @State private var packageInfo: PackageInfoState?

    var body: some View {
        HSplitView {
            // Results list
            VStack(spacing: 0) {
                searchField
                Divider()
                resultsList
            }
            .frame(minWidth: 300)

            // Detail pane
            if let selected = selectedResult {
                SearchResultDetailView(
                    item: selected,
                    packageInfo: packageInfo,
                    appState: appState
                )
            } else {
                noSelectionView
            }
        }
        .navigationTitle("Search")
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search formulae and casks...", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    Task { await performSearch() }
                }

            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                    searchResults = nil
                    selectedResult = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    private var resultsList: some View {
        Group {
            if let results = searchResults {
                if results.isEmpty {
                    EmptyStateView(
                        title: "No Results",
                        message: "No packages found matching '\(searchQuery)'",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    List(selection: $selectedResult) {
                        if !results.formulae.isEmpty {
                            Section("Formulae (\(results.formulae.count))") {
                                ForEach(results.formulae, id: \.self) { name in
                                    SearchResultRow(
                                        name: name,
                                        isCask: false,
                                        hasOtherType: results.casks.contains(name),
                                        appState: appState
                                    )
                                    .tag(SearchResultItem(name: name, isCask: false))
                                }
                            }
                        }

                        if !results.casks.isEmpty {
                            Section("Casks (\(results.casks.count))") {
                                ForEach(results.casks, id: \.self) { name in
                                    SearchResultRow(
                                        name: name,
                                        isCask: true,
                                        hasOtherType: results.formulae.contains(name),
                                        appState: appState
                                    )
                                    .tag(SearchResultItem(name: name, isCask: true))
                                }
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)

                    Text("Search Homebrew")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("Search for formulae and casks to install")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: selectedResult) { _, newValue in
            if let item = newValue {
                Task { await loadPackageInfo(item) }
            } else {
                packageInfo = nil
            }
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        selectedResult = nil
        packageInfo = nil

        do {
            searchResults = try await brewService.search(query: searchQuery)
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isSearching = false
    }

    private func loadPackageInfo(_ item: SearchResultItem) async {
        packageInfo = .loading

        do {
            if item.isCask {
                let cask = try await brewService.getCaskInfo(name: item.name)
                let isInstalled = appState.installedCasks.contains { $0.token == item.name }
                packageInfo = .loaded(PackageDetails(
                    name: cask.displayName,
                    identifier: cask.token,
                    version: cask.version,
                    description: cask.description,
                    homepage: cask.homepage,
                    isCask: true,
                    isInstalled: isInstalled,
                    dependencies: []
                ))
            } else {
                let formula = try await brewService.getFormulaInfo(name: item.name)
                let isInstalled = appState.installedFormulae.contains { $0.name == item.name }
                packageInfo = .loaded(PackageDetails(
                    name: formula.name,
                    identifier: formula.name,
                    version: formula.version,
                    description: formula.description,
                    homepage: formula.homepage,
                    isCask: false,
                    isInstalled: isInstalled,
                    dependencies: formula.dependencies
                ))
            }
        } catch {
            packageInfo = .error(error.localizedDescription)
        }
    }
}

/// Represents a search result item
struct SearchResultItem: Identifiable, Hashable {
    let name: String
    let isCask: Bool

    var id: String { "\(isCask ? "cask" : "formula")-\(name)" }
}

/// State for package info loading
enum PackageInfoState {
    case loading
    case loaded(PackageDetails)
    case error(String)
}

/// Details about a package for display
struct PackageDetails {
    let name: String
    let identifier: String
    let version: String
    let description: String?
    let homepage: String?
    let isCask: Bool
    let isInstalled: Bool
    let dependencies: [String]
}

/// Row for a search result
struct SearchResultRow: View {
    let name: String
    let isCask: Bool
    let hasOtherType: Bool
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCask ? "app.badge" : "terminal")
                .foregroundStyle(isCask ? .purple : .blue)
                .frame(width: 20)

            Text(name)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
        .contextMenu {
            // Install
            Button {
                Task {
                    await installPackage()
                }
            } label: {
                Label("Install", systemImage: "arrow.down.circle")
            }

            // Install as Cask / Formula if both exist
            if hasOtherType {
                Button {
                    Task {
                        await installPackage(asOtherType: true)
                    }
                } label: {
                    Label(isCask ? "Install as Formula" : "Install as Cask", systemImage: isCask ? "terminal" : "app.badge")
                }
            }

            Divider()

            // Open Homepage (try to get package info first)
            Button {
                Task {
                    await openHomepage()
                }
            } label: {
                Label("Open Homepage", systemImage: "globe")
            }

            // Copy Package Name
            Button {
                copyPackageName()
            } label: {
                Label("Copy Package Name", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - Actions

    private func installPackage(asOtherType: Bool = false) async {
        let installAsCask = asOtherType ? !isCask : isCask
        appState.isOperationInProgress = true
        appState.currentOperation = "Installing \(name)..."
        appState.clearOperationOutput()

        let stream = await brewService.install(packageName: name, isCask: installAsCask, adopt: false)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh installed packages
        do {
            if installAsCask {
                appState.installedCasks = try await brewService.getInstalledCasks()
            } else {
                appState.installedFormulae = try await brewService.getInstalledFormulae()
            }
        } catch {
            // Ignore refresh errors
        }

        appState.isOperationInProgress = false
    }

    private func openHomepage() async {
        do {
            if isCask {
                let cask = try await brewService.getCaskInfo(name: name)
                if let homepage = cask.homepage, let url = URL(string: homepage) {
                    openURL(url)
                }
            } else {
                let formula = try await brewService.getFormulaInfo(name: name)
                if let homepage = formula.homepage, let url = URL(string: homepage) {
                    openURL(url)
                }
            }
        } catch {
            // Silently fail if we can't get the homepage
        }
    }

    private func copyPackageName() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(name, forType: .string)
    }
}

/// Detail view for a search result
struct SearchResultDetailView: View {
    let item: SearchResultItem
    let packageInfo: PackageInfoState?
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @Environment(\.openURL) private var openURL

    @State private var isInstalling = false
    @State private var adoptExisting = false

    var body: some View {
        Group {
            switch packageInfo {
            case .loading:
                LoadingView(message: "Loading package info...")
            case .loaded(let details):
                detailContent(details)
            case .error(let message):
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Failed to load info")
                        .font(.headline)
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case nil:
                EmptyView()
            }
        }
        .frame(minWidth: 300)
    }

    private func detailContent(_ details: PackageDetails) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(details.isCask ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: details.isCask ? "app.badge" : "terminal")
                            .font(.system(size: 28))
                            .foregroundStyle(details.isCask ? .purple : .blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(details.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        HStack(spacing: 8) {
                            Label(details.version, systemImage: "tag")
                            Text("•")
                            Text(details.isCask ? "Cask" : "Formula")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if details.isInstalled {
                        Label("Installed", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Divider()

                // Description
                if let description = details.description {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(description)
                            .foregroundStyle(.secondary)
                    }
                }

                // Homepage
                if let homepage = details.homepage, let url = URL(string: homepage) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Homepage")
                            .font(.headline)
                        Button {
                            openURL(url)
                        } label: {
                            Text(homepage)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Dependencies
                if !details.dependencies.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dependencies")
                            .font(.headline)
                        FlowLayout(spacing: 8) {
                            ForEach(details.dependencies, id: \.self) { dep in
                                Text(dep)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }

                // Install button
                if !details.isInstalled {
                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        // Adopt toggle for casks only
                        if details.isCask {
                            Toggle(isOn: $adoptExisting) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Adopt existing app")
                                        .font(.subheadline)
                                    Text("Use if the app is already installed outside of Homebrew")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Button {
                            Task { await installPackage(details) }
                        } label: {
                            if isInstalling {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Label("Install", systemImage: "arrow.down.circle")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling || appState.isOperationInProgress)
                    }
                }
            }
            .padding(24)
        }
    }

    private func installPackage(_ details: PackageDetails) async {
        isInstalling = true
        appState.isOperationInProgress = true
        appState.currentOperation = "Installing \(details.name)..."
        appState.clearOperationOutput()

        // Use adopt flag for casks when toggle is enabled
        let shouldAdopt = details.isCask && adoptExisting
        let stream = await brewService.install(packageName: details.identifier, isCask: details.isCask, adopt: shouldAdopt)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh installed packages
        do {
            if details.isCask {
                appState.installedCasks = try await brewService.getInstalledCasks()
            } else {
                appState.installedFormulae = try await brewService.getInstalledFormulae()
            }
        } catch {
            // Ignore refresh errors
        }

        appState.isOperationInProgress = false
        appState.currentOperation = nil
        isInstalling = false
    }
}

#Preview {
    SearchView(appState: AppState())
}
