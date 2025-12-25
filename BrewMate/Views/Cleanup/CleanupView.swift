import SwiftUI

/// View for cleaning up Homebrew cache and old package versions
struct CleanupView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var isLoading = false
    @State private var isRunningCleanup = false
    @State private var dryRunResult: CleanupResult?
    @State private var cleanupOutput: [String] = []
    @State private var showCleanupOutput = false
    @State private var diskUsage: DiskUsageInfo?

    var body: some View {
        Group {
            if LicenseManager.shared.isPro {
                cleanupContent
            } else {
                InlinePaywallView(feature: .cleanup)
            }
        }
    }

    private var cleanupContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Disk Usage Overview
                diskUsageSection

                Divider()

                // Cleanup Preview
                previewSection

                Divider()

                // Actions
                actionsSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadData()
        }
        .sheet(isPresented: $showCleanupOutput) {
            cleanupOutputSheet
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cleanup")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Remove old package versions, clear downloads cache, and free up disk space")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var diskUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Disk Usage")
                    .font(.headline)

                Spacer()

                Button {
                    Task { await loadDiskUsage() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }

            if isLoading && diskUsage == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if let usage = diskUsage {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    DiskUsageCard(
                        title: "Cache",
                        size: usage.formattedCacheSize,
                        icon: "arrow.down.circle.fill",
                        color: .blue,
                        description: "Downloaded packages"
                    )

                    DiskUsageCard(
                        title: "Cellar",
                        size: usage.formattedCellarSize,
                        icon: "shippingbox.fill",
                        color: .green,
                        description: "Installed formulae"
                    )

                    DiskUsageCard(
                        title: "Caskroom",
                        size: usage.formattedCaskroomSize,
                        icon: "app.fill",
                        color: .purple,
                        description: "Installed casks"
                    )
                }

                HStack {
                    Text("Total Homebrew usage:")
                        .foregroundStyle(.secondary)
                    Text(usage.formattedTotalSize)
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .padding(.top, 8)
            } else {
                Text("Unable to load disk usage")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cleanup Preview")
                    .font(.headline)

                Spacer()

                Button {
                    Task { await runDryRun() }
                } label: {
                    if isLoading && dryRunResult == nil {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Scan", systemImage: "magnifyingglass")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }

            if let result = dryRunResult {
                VStack(alignment: .leading, spacing: 12) {
                    if !result.formulaeRemoved.isEmpty {
                        CleanupCategoryView(
                            title: "Old Formula Versions",
                            items: result.formulaeRemoved,
                            icon: "terminal",
                            color: .blue
                        )
                    }

                    if !result.casksRemoved.isEmpty {
                        CleanupCategoryView(
                            title: "Old Cask Versions",
                            items: result.casksRemoved,
                            icon: "app.badge",
                            color: .purple
                        )
                    }

                    if result.bytesFreed > 0 {
                        HStack {
                            Image(systemName: "externaldrive.fill")
                                .foregroundStyle(.green)
                            Text("Space to be freed:")
                            Text(result.formattedBytesFreed)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                        }
                        .padding(.top, 8)
                    }

                    if result.formulaeRemoved.isEmpty && result.casksRemoved.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Your Homebrew installation is clean!")
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)

                    Text("Click \"Scan\" to preview what will be cleaned")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)

            HStack(spacing: 16) {
                Button {
                    Task { await runCleanup(pruneAll: false) }
                } label: {
                    Label("Standard Cleanup", systemImage: "trash")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningCleanup || isLoading)
                .help("Remove old versions and outdated downloads")

                Button {
                    Task { await runCleanup(pruneAll: true) }
                } label: {
                    Label("Deep Cleanup", systemImage: "trash.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isRunningCleanup || isLoading)
                .help("Remove all cached downloads (--prune=all)")
            }

            Text("Standard cleanup removes old versions. Deep cleanup also clears all cached downloads.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var cleanupOutputSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Cleanup Progress")
                    .font(.headline)

                Spacer()

                if isRunningCleanup {
                    ProgressView()
                        .controlSize(.small)
                }

                Button("Done") {
                    showCleanupOutput = false
                }
                .disabled(isRunningCleanup)
            }
            .padding()

            Divider()

            ScrollView {
                ScrollViewReader { proxy in
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(cleanupOutput.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: cleanupOutput.count) { _, newCount in
                        if newCount > 0 {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    // MARK: - Actions

    private func loadData() async {
        await loadDiskUsage()
        await runDryRun()
    }

    private func loadDiskUsage() async {
        isLoading = true
        do {
            diskUsage = try await brewService.getDiskUsage()
        } catch {
            // Silently fail - disk usage is optional
        }
        isLoading = false
    }

    private func runDryRun() async {
        isLoading = true
        do {
            dryRunResult = try await brewService.cleanup(dryRun: true)
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
        isLoading = false
    }

    private func runCleanup(pruneAll: Bool) async {
        isRunningCleanup = true
        cleanupOutput = []
        showCleanupOutput = true

        cleanupOutput.append("Starting cleanup\(pruneAll ? " (deep)" : "")...")

        do {
            if pruneAll {
                // Deep cleanup with prune=all
                try await brewService.clearCache()
                cleanupOutput.append("Cache cleared successfully")
            }

            // Run standard cleanup
            let result = try await brewService.cleanup(dryRun: false)

            if !result.formulaeRemoved.isEmpty {
                cleanupOutput.append("\nRemoved formula versions:")
                for formula in result.formulaeRemoved {
                    cleanupOutput.append("  - \(formula)")
                }
            }

            if !result.casksRemoved.isEmpty {
                cleanupOutput.append("\nRemoved cask versions:")
                for cask in result.casksRemoved {
                    cleanupOutput.append("  - \(cask)")
                }
            }

            cleanupOutput.append("\nFreed \(result.formattedBytesFreed) of disk space")
            cleanupOutput.append("\nCleanup completed successfully!")

            // Refresh data
            await loadDiskUsage()
            dryRunResult = nil
        } catch {
            cleanupOutput.append("\nError: \(error.localizedDescription)")
        }

        isRunningCleanup = false
    }
}

// MARK: - Supporting Views

struct DiskUsageCard: View {
    let title: String
    let size: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .fontWeight(.medium)
            }

            Text(size)
                .font(.title2)
                .fontWeight(.bold)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct CleanupCategoryView: View {
    let title: String
    let items: [String]
    let icon: String
    let color: Color

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                    Text(title)
                        .fontWeight(.medium)
                    Text("(\(items.count))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items, id: \.self) { item in
                        Text("• \(item)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    CleanupView(appState: AppState())
}
