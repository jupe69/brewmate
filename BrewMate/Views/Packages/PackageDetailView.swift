import SwiftUI

/// Detail view showing information about a selected package
struct PackageDetailView: View {
    let package: Package
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @Environment(\.openURL) private var openURL

    @AppStorage("confirmBeforeUninstall") private var confirmBeforeUninstall = true
    @AppStorage("showDependencies") private var showDependencies = true

    @State private var showUninstallConfirmation = false
    @State private var isUninstalling = false
    @State private var detailedInfo: DetailedPackageInfo?
    @State private var isLoadingInfo = false
    @State private var noteText: String = ""
    @State private var isPinning = false
    @State private var appPath: String?
    @State private var isQuarantined: Bool?
    @State private var showRemoveQuarantineConfirmation = false
    @State private var showFavoritesPaywall = false
    @State private var showPinningPaywall = false

    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                Divider()
            }
            .padding(24)
            .padding(.bottom, 0)

            // Tab view for different sections
            TabView {
                // Overview Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Description
                        if let description = package.description {
                            descriptionSection(description)
                        }

                        // Quick Info
                        quickInfoSection

                        // Notes section
                        notesSection

                        // Dependencies (for formulae) - simple list (if enabled in settings)
                        if showDependencies, case .formula(let formula) = package, !formula.dependencies.isEmpty {
                            dependenciesSection(formula.dependencies)
                        }

                        // Actions
                        actionsSection
                    }
                    .padding(24)
                }
                .tabItem {
                    Label("Overview", systemImage: "info.circle")
                }

                // Dependencies Tab (for formulae only, if enabled in settings)
                if showDependencies && package.isFormula {
                    DependencyTreeView(package: package)
                        .tabItem {
                            Label("Dependencies", systemImage: "arrow.down.circle")
                        }
                }
            }
            .frame(minHeight: 200)
        }
        .frame(minWidth: 300, minHeight: 400)
        .navigationTitle(package.name)
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
            Text("This will remove \(package.name) from your system. This action cannot be undone.")
        }
        .confirmationDialog(
            "Remove Quarantine Attribute?",
            isPresented: $showRemoveQuarantineConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Quarantine", role: .destructive) {
                Task {
                    await removeQuarantine()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will disable macOS Gatekeeper protection for \(package.name). Only do this if you trust the source of this application.")
        }
        .task {
            await loadDetailedInfo()
        }
        .sheet(isPresented: $showFavoritesPaywall) {
            PaywallView(feature: .favorites)
        }
        .sheet(isPresented: $showPinningPaywall) {
            PaywallView(feature: .pinning)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Package icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(package.isCask ? Color.purple.opacity(0.15) : Color.blue.opacity(0.15))
                    .frame(width: 64, height: 64)

                Image(systemName: package.isCask ? "app.badge" : "terminal")
                    .font(.system(size: 28))
                    .foregroundStyle(package.isCask ? .purple : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 8) {
                    Label(package.version, systemImage: "tag")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(package.isCask ? "Cask" : "Formula")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Favorite button (Pro feature)
            Button {
                if LicenseManager.shared.isPro {
                    appState.userDataManager.toggleFavorite(package.packageName)
                } else {
                    showFavoritesPaywall = true
                }
            } label: {
                Image(systemName: appState.userDataManager.isFavorite(package.packageName) ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundStyle(appState.userDataManager.isFavorite(package.packageName) ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .help(LicenseManager.shared.isPro
                ? (appState.userDataManager.isFavorite(package.packageName) ? "Remove from favorites" : "Add to favorites")
                : "Pro feature: Add to favorites")

            if isOutdated {
                updateBadge
            }
        }
    }

    private var updateBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
            Text("Update Available")
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.orange)
        .clipShape(Capsule())
    }

    private func descriptionSection(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var quickInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible(), alignment: .leading),
                GridItem(.flexible(), alignment: .leading)
            ], spacing: 12) {
                InfoRow(label: "Version", value: package.version)

                if let homepage = package.homepage {
                    InfoRow(label: "Homepage", value: homepage, isLink: true) {
                        if let url = URL(string: homepage) {
                            openURL(url)
                        }
                    }
                }

                InfoRow(label: "Type", value: package.isCask ? "Cask (GUI App)" : "Formula (CLI)")

                if case .formula(let formula) = package {
                    InfoRow(
                        label: "Installed as",
                        value: formula.installedAsDependency ? "Dependency" : "Direct install"
                    )
                }

                // Show quarantine status for casks
                if package.isCask {
                    if let appPath = appPath {
                        InfoRow(label: "Location", value: appPath)
                    }

                    if let isQuarantined = isQuarantined {
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quarantine Status")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)

                                HStack(spacing: 4) {
                                    Image(systemName: isQuarantined ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                                        .foregroundStyle(isQuarantined ? .orange : .green)
                                    Text(isQuarantined ? "Quarantined" : "Not Quarantined")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }

                            if isQuarantined {
                                Button("Remove") {
                                    showRemoveQuarantineConfirmation = true
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dependenciesSection(_ dependencies: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Dependencies")
                .font(.headline)

            FlowLayout(spacing: 8) {
                ForEach(dependencies, id: \.self) { dep in
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

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.headline)
                if !LicenseManager.shared.isPro {
                    Text("PRO")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                Spacer()
                if LicenseManager.shared.isPro && appState.userDataManager.hasNote(for: package.packageName) {
                    Button("Clear") {
                        appState.userDataManager.removeNote(for: package.packageName)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }

            if LicenseManager.shared.isPro {
                TextEditor(text: Binding(
                    get: { appState.userDataManager.getNote(for: package.packageName) ?? "" },
                    set: { appState.userDataManager.setNote($0, for: package.packageName) }
                ))
                .font(.body)
                .frame(minHeight: 60, maxHeight: 100)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                    Text("Upgrade to Pro to add notes")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(height: 60)
                .frame(minWidth: 200)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    showFavoritesPaywall = true
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 12) {
                if isOutdated {
                    Button {
                        Task {
                            await upgradePackage()
                        }
                    } label: {
                        Label("Update", systemImage: "arrow.up.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isUninstalling || appState.isOperationInProgress)
                }

                // Pin/Unpin button (only for formulae, Pro feature)
                if package.isFormula {
                    Button {
                        if LicenseManager.shared.isPro {
                            Task {
                                await togglePin()
                            }
                        } else {
                            showPinningPaywall = true
                        }
                    } label: {
                        if isPinning {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label(isPinned ? "Unpin" : "Pin", systemImage: isPinned ? "pin.slash" : "pin.fill")
                        }
                    }
                    .disabled(isPinning || isUninstalling || appState.isOperationInProgress)
                }

                Button(role: .destructive) {
                    if confirmBeforeUninstall {
                        showUninstallConfirmation = true
                    } else {
                        Task {
                            await uninstallPackage()
                        }
                    }
                } label: {
                    if isUninstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Uninstall", systemImage: "trash")
                    }
                }
                .disabled(isUninstalling || appState.isOperationInProgress)
            }
        }
    }

    // MARK: - Computed Properties

    private var isOutdated: Bool {
        appState.outdatedPackages.contains { $0.name == package.packageName }
    }

    private var outdatedInfo: OutdatedPackage? {
        appState.outdatedPackages.first { $0.name == package.packageName }
    }

    private var isPinned: Bool {
        appState.pinnedPackages.contains(package.packageName)
    }

    // MARK: - Actions

    private func loadDetailedInfo() async {
        isLoadingInfo = true

        // For casks, check app path and quarantine status
        if package.isCask {
            do {
                appPath = try await brewService.getCaskInstallPath(caskName: package.packageName)

                // Check if the app is quarantined
                if let path = appPath {
                    let quarantinedApps = try await brewService.getQuarantinedApps()
                    isQuarantined = quarantinedApps.contains { $0.path == path }
                }
            } catch {
                // Silently fail - quarantine check is optional
                appPath = nil
                isQuarantined = nil
            }
        }

        isLoadingInfo = false
    }

    private func uninstallPackage() async {
        isUninstalling = true

        do {
            try await brewService.uninstall(packageName: package.packageName, isCask: package.isCask)

            // Refresh the package lists
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
            appState.selectedPackage = nil
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isUninstalling = false
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

    private func removeQuarantine() async {
        guard let path = appPath else { return }

        do {
            try await brewService.removeQuarantine(appPath: path)

            // Refresh quarantine status
            await loadDetailedInfo()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }

    private func togglePin() async {
        isPinning = true

        do {
            if isPinned {
                try await brewService.unpinPackage(name: package.packageName)
                appState.pinnedPackages.remove(package.packageName)
            } else {
                try await brewService.pinPackage(name: package.packageName)
                appState.pinnedPackages.insert(package.packageName)
            }
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isPinning = false
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    var isLink: Bool = false
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)

            if isLink, let action {
                Button(action: action) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
            } else {
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
        }
    }
}

/// A simple flow layout for displaying tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                     y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

struct DetailedPackageInfo {
    let installedDate: Date?
    let size: Int64?
}

#Preview {
    let state = AppState()
    let formula = Formula(
        name: "git",
        fullName: "git",
        version: "2.43.0",
        description: "Distributed revision control system. Git is a free and open source distributed version control system designed to handle everything from small to very large projects with speed and efficiency.",
        homepage: "https://git-scm.com",
        installedAsDependency: false,
        dependencies: ["gettext", "pcre2"],
        installedOn: Date()
    )

    return NavigationStack {
        PackageDetailView(package: .formula(formula), appState: state)
    }
    .frame(width: 500, height: 600)
}
