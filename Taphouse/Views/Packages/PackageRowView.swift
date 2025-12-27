import SwiftUI

/// A row displaying a single package in the list
struct PackageRowView: View {
    let package: Package
    var isOutdated: Bool = false
    var isPinned: Bool = false
    var isDependency: Bool = false  // True if package is only installed as a dependency
    var isSelectionMode: Bool = false
    var isSelected: Bool = false
    var onToggleSelection: (() -> Void)?
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @Environment(\.openURL) private var openURL

    @State private var showUninstallConfirmation = false

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox in selection mode
            if isSelectionMode {
                Button {
                    onToggleSelection?()
                } label: {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }

            // Package icon
            AppIconView(packageName: package.name, isCask: package.isCask, size: 28)

            // Package info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(package.name)
                        .font(.headline)
                        .lineLimit(1)

                    if isOutdated {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    if isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if isDependency {
                        Text("dep")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .foregroundStyle(.secondary)
                            .cornerRadius(3)
                            .help("Installed as a dependency")
                    }
                }

                if let description = package.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Version
            Text(package.version)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            // Open Homepage
            if let homepage = package.homepage, let url = URL(string: homepage) {
                Button {
                    openURL(url)
                } label: {
                    Label("Open Homepage", systemImage: "globe")
                }
            }

            // Copy Package Name
            Button {
                copyPackageName()
            } label: {
                Label("Copy Package Name", systemImage: "doc.on.doc")
            }

            // Pin/Unpin (only for formulae, not casks)
            if !package.isCask {
                Button {
                    Task {
                        await togglePin()
                    }
                } label: {
                    Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin")
                }
            }

            Divider()

            // Upgrade (if outdated)
            if isOutdated {
                Button {
                    Task {
                        await upgradePackage()
                    }
                } label: {
                    Label("Upgrade", systemImage: "arrow.up.circle")
                }
            }

            // Reinstall
            Button {
                Task {
                    await reinstallPackage()
                }
            } label: {
                Label("Reinstall", systemImage: "arrow.clockwise")
            }

            Divider()

            // Uninstall
            Button(role: .destructive) {
                showUninstallConfirmation = true
            } label: {
                Label("Uninstall", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Uninstall \(package.name)?",
            isPresented: $showUninstallConfirmation,
            titleVisibility: .visible
        ) {
            Button("Uninstall", role: .destructive) {
                Task {
                    await uninstallPackage()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove \(package.name) from your system.")
        }
    }

    // MARK: - Actions

    private func copyPackageName() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(package.packageName, forType: .string)
    }

    private func togglePin() async {
        do {
            if isPinned {
                try await brewService.unpin(packageName: package.packageName)
                appState.pinnedPackages.remove(package.packageName)
            } else {
                try await brewService.pin(packageName: package.packageName)
                appState.pinnedPackages.insert(package.packageName)
            }
            // Refresh outdated packages to update pin status
            appState.outdatedPackages = try await brewService.getOutdated()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }

    private func upgradePackage() async {
        appState.isOperationInProgress = true
        appState.currentOperation = "Upgrading \(package.name)..."
        appState.clearOperationOutput()

        let stream = await brewService.upgrade(packageName: package.packageName)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh
        do {
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
            appState.outdatedPackages = try await brewService.getOutdated()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }

    private func reinstallPackage() async {
        appState.isOperationInProgress = true
        appState.currentOperation = "Reinstalling \(package.name)..."
        appState.clearOperationOutput()

        let stream = await brewService.reinstall(packageName: package.packageName, isCask: package.isCask)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh
        do {
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }

    private func uninstallPackage() async {
        appState.isOperationInProgress = true
        appState.currentOperation = "Uninstalling \(package.name)..."

        do {
            try await brewService.uninstall(packageName: package.packageName, isCask: package.isCask)

            // Refresh the package lists
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
            appState.selectedPackage = nil
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }
}

/// A compact row for smaller list views
struct CompactPackageRow: View {
    let package: Package

    var body: some View {
        HStack {
            Image(systemName: package.isCask ? "app.badge" : "terminal")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(package.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(package.version)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

/// Row for outdated packages with version comparison
struct OutdatedPackageRow: View {
    let package: OutdatedPackage
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.isCask ? "app.badge" : "terminal")
                .font(.title3)
                .foregroundStyle(package.isCask ? .purple : .blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(package.name)
                        .font(.headline)

                    if package.pinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 4) {
                    Text(package.installedVersion)
                        .foregroundStyle(.secondary)

                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    Text(package.currentVersion)
                        .foregroundStyle(.green)
                }
                .font(.caption)
                .monospacedDigit()
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            // Upgrade
            Button {
                Task {
                    await upgradePackage()
                }
            } label: {
                Label("Upgrade", systemImage: "arrow.up.circle")
            }

            // Pin (Skip Updates) - only for formulae, not casks
            if !package.isCask {
                Button {
                    Task {
                        await togglePin()
                    }
                } label: {
                    Label(package.pinned ? "Unpin" : "Pin (Skip Updates)", systemImage: package.pinned ? "pin.slash" : "pin")
                }
            }

            // View Details (select the package in the list)
            Button {
                selectPackage()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }
        }
    }

    // MARK: - Actions

    private func upgradePackage() async {
        appState.isOperationInProgress = true
        appState.currentOperation = "Upgrading \(package.name)..."
        appState.clearOperationOutput()

        let stream = await brewService.upgrade(packageName: package.name)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh
        do {
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
            appState.outdatedPackages = try await brewService.getOutdated()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
    }

    private func togglePin() async {
        do {
            if package.pinned {
                try await brewService.unpin(packageName: package.name)
                appState.pinnedPackages.remove(package.name)
            } else {
                try await brewService.pin(packageName: package.name)
                appState.pinnedPackages.insert(package.name)
            }
            // Refresh outdated packages to update pin status
            appState.outdatedPackages = try await brewService.getOutdated()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }

    private func selectPackage() {
        // Find the package in installed packages and select it
        if let matchingPackage = appState.allInstalledPackages.first(where: { $0.packageName == package.name }) {
            appState.selectedPackage = matchingPackage
            appState.selectedSection = .installed
        }
    }
}

/// Row for brew services
struct ServiceRowView: View {
    let service: BrewServiceInfo
    var onAction: ((ServiceAction) -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(Color.serviceStatus(service.status))
                .frame(width: 10, height: 10)

            // Service info
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(service.status.displayName)
                        .foregroundStyle(.secondary)

                    if let user = service.user {
                        Text("(\(user))")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.caption)
            }

            Spacer()

            // Action buttons
            if let onAction {
                HStack(spacing: 4) {
                    if service.status.isActive {
                        Button {
                            onAction(.stop)
                        } label: {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Stop")

                        Button {
                            onAction(.restart)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("Restart")
                    } else {
                        Button {
                            onAction(.start)
                        } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(.borderless)
                        .help("Start")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            if let onAction {
                // Start/Stop based on current state
                if service.status.isActive {
                    Button {
                        onAction(.stop)
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                    }
                } else {
                    Button {
                        onAction(.start)
                    } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                }

                // Restart
                Button {
                    onAction(.restart)
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }

                // Open Log File (if available)
                if let logFile = service.file {
                    Divider()
                    Button {
                        openLogFile(path: logFile)
                    } label: {
                        Label("Open Log File", systemImage: "doc.text")
                    }
                }
            }
        }
    }

    private func openLogFile(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }
}

#Preview("Package Row") {
    @Previewable @State var previewState = AppState()
    List {
        PackageRowView(
            package: .formula(Formula(
                name: "git",
                fullName: "git",
                version: "2.43.0",
                description: "Distributed revision control system",
                homepage: "https://git-scm.com",
                installedAsDependency: false,
                dependencies: [],
                installedOn: nil
            )),
            appState: previewState
        )

        PackageRowView(
            package: .cask(Cask(
                token: "visual-studio-code",
                name: ["Visual Studio Code"],
                version: "1.85.0",
                description: "Open-source code editor",
                homepage: "https://code.visualstudio.com"
            )),
            isOutdated: true,
            appState: previewState
        )
    }
    .frame(width: 400, height: 200)
}

#Preview("Outdated Row") {
    @Previewable @State var previewState = AppState()
    List {
        OutdatedPackageRow(
            package: OutdatedPackage(
                name: "node",
                installedVersion: "20.10.0",
                currentVersion: "21.5.0",
                isCask: false
            ),
            appState: previewState
        )
    }
    .frame(width: 400, height: 100)
}

#Preview("Service Row") {
    List {
        ServiceRowView(
            service: BrewServiceInfo(
                name: "postgresql@16",
                status: .running,
                user: "user",
                file: nil
            )
        ) { _ in }

        ServiceRowView(
            service: BrewServiceInfo(
                name: "redis",
                status: .stopped,
                user: nil,
                file: nil
            )
        ) { _ in }
    }
    .frame(width: 400, height: 200)
}
