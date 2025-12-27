import SwiftUI

/// View for discovering popular packages organized by category
struct DiscoverView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var isLoading = false
    @State private var isPreparingView = true  // Shows loading while view renders
    @State private var visibleCategoryCount = 0  // Progressive loading of categories
    @State private var packagesByCategory: [PackageCategory: [PopularPackage]] = [:]
    @State private var packageDescriptions: [String: String] = [:]
    @State private var installedPackages: Set<String> = []
    @State private var selectedCategory: PackageCategory?
    @State private var installingPackage: String?
    @State private var error: String?

    // Order categories for display
    private let categoryOrder: [PackageCategory] = [
        .development, .cloud, .utilities, .databases,
        .productivity, .media, .communication, .browsers,
        .security, .other
    ]

    var body: some View {
        HSplitView {
            // Categories sidebar
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Categories")
                        .font(.headline)
                    Spacer()
                    Button {
                        Task { await loadPopularPackages() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
                .padding(12)

                Divider()

                List(selection: $selectedCategory) {
                    Button {
                        selectedCategory = nil
                    } label: {
                        Label("All Categories", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(selectedCategory == nil ? Color.accentColor.opacity(0.15) : Color.clear)

                    Divider()

                    ForEach(categoryOrder) { category in
                        if let packages = packagesByCategory[category], !packages.isEmpty {
                            CategoryRow(
                                category: category,
                                count: packages.count,
                                isSelected: selectedCategory == category
                            )
                            .tag(category)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 180, maxWidth: 220)

            // Main content
            if let category = selectedCategory {
                categoryDetailView(for: category)
            } else {
                allCategoriesGrid
            }
        }
        .navigationTitle("Discover")
        .task {
            await loadPopularPackages()
        }
    }

    private var allCategoriesGrid: some View {
        Group {
            if isLoading || isPreparingView {
                // Loading state - no content rendered yet
                LoadingView(message: isLoading ? "Loading popular packages..." : "Preparing view...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                EmptyStateView(
                    title: "Failed to Load",
                    message: error,
                    systemImage: "exclamationmark.triangle"
                )
            } else if packagesByCategory.isEmpty {
                EmptyStateView(
                    title: "No Packages",
                    message: "Unable to load popular packages",
                    systemImage: "shippingbox"
                )
            } else {
                // Main content - categories load progressively
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Discover")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            Text("Popular packages from Homebrew analytics")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.bottom, 8)

                        // Show categories progressively
                        ForEach(Array(categoryOrder.prefix(visibleCategoryCount).enumerated()), id: \.element) { _, category in
                            if let packages = packagesByCategory[category], !packages.isEmpty {
                                CategorySection(
                                    category: category,
                                    packages: packages,
                                    descriptions: packageDescriptions,
                                    installedPackages: installedPackages,
                                    installingPackage: installingPackage,
                                    onInstall: { package in
                                        Task { await installPackage(package) }
                                    },
                                    onShowAll: {
                                        selectedCategory = category
                                    },
                                    onLoadDescription: { package in
                                        Task { await loadDescription(for: package) }
                                    }
                                )
                            }
                        }

                        // Loading more indicator
                        if visibleCategoryCount < categoryOrder.count {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading more...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding(24)
                }
                .overlay(alignment: .top) {
                    IconLoadingBanner()
                        .padding(.top, 8)
                }
                .task {
                    await loadCategoriesProgressively()
                }
            }
        }
    }

    private func categoryDetailView(for category: PackageCategory) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Category header
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 56, height: 56)
                        Image(systemName: category.systemImage)
                            .font(.title)
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue)
                            .font(.title)
                            .fontWeight(.bold)
                        if let packages = packagesByCategory[category] {
                            Text("\(packages.count) popular packages")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.bottom, 8)

                // Package grid
                if let packages = packagesByCategory[category] {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(packages) { package in
                            LargePackageCard(
                                package: package,
                                description: packageDescriptions[package.name],
                                isInstalled: installedPackages.contains(package.name),
                                isInstalling: installingPackage == package.name,
                                onInstall: {
                                    Task { await installPackage(package) }
                                }
                            )
                            .onAppear {
                                if packageDescriptions[package.name] == nil {
                                    Task { await loadDescription(for: package) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .overlay(alignment: .top) {
            IconLoadingBanner()
                .padding(.top, 8)
        }
    }

    // MARK: - Actions

    private func loadPopularPackages() async {
        isLoading = true
        isPreparingView = true
        error = nil

        do {
            // Load popular packages and installed packages in parallel
            async let popularTask = brewService.getPopularPackagesByCategory()
            async let formulaeTask = brewService.getInstalledFormulae()
            async let casksTask = brewService.getInstalledCasks()

            let (popular, formulae, casks) = try await (popularTask, formulaeTask, casksTask)
            packagesByCategory = popular

            // Build set of installed package names
            var installed = Set<String>()
            for formula in formulae {
                installed.insert(formula.name)
            }
            for cask in casks {
                installed.insert(cask.token)
            }
            installedPackages = installed
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
        isPreparingView = false

        // Start with first 2 categories visible
        visibleCategoryCount = 2
    }

    private func loadCategoriesProgressively() async {
        // Add remaining categories one at a time with small delay
        while visibleCategoryCount < categoryOrder.count {
            try? await Task.sleep(for: .milliseconds(150))
            visibleCategoryCount += 1
        }
    }

    private func loadDescription(for package: PopularPackage) async {
        guard packageDescriptions[package.name] == nil else { return }

        do {
            let description = try await brewService.getPackageDescription(
                name: package.name,
                isCask: package.isCask
            )
            packageDescriptions[package.name] = description
        } catch {
            // Silently fail - description is optional
        }
    }

    private func installPackage(_ package: PopularPackage) async {
        installingPackage = package.name

        appState.currentOperation = "Installing \(package.name)..."
        appState.isOperationInProgress = true
        appState.clearOperationOutput()

        for await line in await brewService.install(packageName: package.name, isCask: package.isCask, adopt: false) {
            appState.appendOperationOutput(line)
        }

        appState.isOperationInProgress = false
        installingPackage = nil

        // Mark as installed after successful install
        installedPackages.insert(package.name)
    }
}

// MARK: - Supporting Views

struct CategoryRow: View {
    let category: PackageCategory
    let count: Int
    let isSelected: Bool

    var body: some View {
        Label {
            HStack {
                Text(category.rawValue)
                Spacer()
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        } icon: {
            Image(systemName: category.systemImage)
        }
    }
}

struct CategorySection: View {
    let category: PackageCategory
    let packages: [PopularPackage]
    let descriptions: [String: String]
    let installedPackages: Set<String>
    let installingPackage: String?
    let onInstall: (PopularPackage) -> Void
    let onShowAll: () -> Void
    let onLoadDescription: (PopularPackage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category header
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: category.systemImage)
                        .foregroundStyle(Color.accentColor)
                }

                Text(category.rawValue)
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button {
                    onShowAll()
                } label: {
                    Text("See All")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            // Horizontal scroll of package cards (lazy for performance)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(packages.prefix(4)) { package in
                        MediumPackageCard(
                            package: package,
                            description: descriptions[package.name],
                            isInstalled: installedPackages.contains(package.name),
                            isInstalling: installingPackage == package.name,
                            onInstall: { onInstall(package) }
                        )
                        .onAppear {
                            onLoadDescription(package)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}

struct MediumPackageCard: View {
    let package: PopularPackage
    let description: String?
    let isInstalled: Bool
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Icon and type badge
            HStack(alignment: .top) {
                AppIconView(packageName: package.name, isCask: package.isCask, size: 48)

                Spacer()

                Text(package.isCask ? "App" : "CLI")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(package.isCask ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                    .foregroundStyle(package.isCask ? .blue : .green)
                    .clipShape(Capsule())
            }

            // Name and description
            VStack(alignment: .leading, spacing: 4) {
                Text(package.name)
                    .font(.headline)
                    .lineLimit(1)

                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(height: 32, alignment: .top)
                } else {
                    Text(" ")
                        .font(.caption)
                        .frame(height: 32)
                }
            }

            Spacer()

            // Stats and install button
            HStack {
                Image(systemName: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(package.formattedCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if isInstalled {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                } else if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button {
                        onInstall()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 200, height: 180)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

struct LargePackageCard: View {
    let package: PopularPackage
    let description: String?
    let isInstalled: Bool
    let isInstalling: Bool
    let onInstall: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            AppIconView(packageName: package.name, isCask: package.isCask, size: 56)

            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(package.name)
                        .font(.headline)

                    Text(package.isCask ? "App" : "CLI")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(package.isCask ? Color.blue.opacity(0.1) : Color.green.opacity(0.1))
                        .foregroundStyle(package.isCask ? .blue : .green)
                        .clipShape(Capsule())
                }

                if let description = description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption2)
                    Text("\(package.formattedCount) installs/month")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Install button or installed indicator
            if isInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Installed")
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            } else if isInstalling {
                ProgressView()
                    .controlSize(.regular)
            } else {
                Button("Install") {
                    onInstall()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

#Preview {
    DiscoverView(appState: AppState())
}
