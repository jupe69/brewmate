import SwiftUI

/// View for system diagnostics, disk usage, and analytics
struct DiagnosticsView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var doctorOutput: [String] = []
    @State private var isRunningDoctor = false
    @State private var diskUsage: DiskUsageInfo?
    @State private var isLoadingDiskUsage = false
    @State private var analyticsEnabled = false
    @State private var isLoadingAnalytics = false
    @State private var isClearingCache = false
    @State private var cacheOutput: [String] = []
    @State private var showCacheOutput = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Diagnostics")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Check system health, manage disk usage, and configure analytics")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Brew Doctor Section
                doctorSection

                Divider()

                // Disk Usage Section
                diskUsageSection

                Divider()

                // Analytics Section
                analyticsSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await loadDiskUsage()
            await loadAnalyticsStatus()
        }
        .sheet(isPresented: $showCacheOutput) {
            OperationOutputView(
                title: "Clearing Cache",
                output: cacheOutput,
                isRunning: isClearingCache
            ) {
                showCacheOutput = false
                cacheOutput.removeAll()
            }
            .frame(minWidth: 600, minHeight: 400)
        }
    }

    // MARK: - Doctor Section

    private var doctorSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Brew Doctor", systemImage: "stethoscope")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await runDoctor()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isRunningDoctor {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.caption)
                        }
                        Text(isRunningDoctor ? "Running..." : "Run Doctor")
                    }
                }
                .disabled(isRunningDoctor)
            }

            Text("Check your Homebrew installation for potential issues")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if !doctorOutput.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(doctorOutput.enumerated()), id: \.offset) { _, line in
                        doctorLine(line)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .cornerRadius(8)
                .font(.system(.body, design: .monospaced))
            } else if !isRunningDoctor {
                Text("Run doctor to check for issues")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            }
        }
    }

    private func doctorLine(_ line: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            if line.contains("Warning:") {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            } else if line.contains("Error:") {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.caption)
            } else if line.contains("Your system is ready to brew") {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.caption)
            }

            Text(line)
                .foregroundStyle(lineColor(for: line))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .textSelection(.enabled)
        }
    }

    private func lineColor(for line: String) -> Color {
        if line.contains("Warning:") {
            return .yellow
        } else if line.contains("Error:") {
            return .red
        } else if line.contains("Your system is ready to brew") {
            return .green
        }
        return .primary
    }

    // MARK: - Disk Usage Section

    private var diskUsageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Disk Usage", systemImage: "internaldrive")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await loadDiskUsage()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isLoadingDiskUsage {
                            ProgressView()
                                .scaleEffect(0.7)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        Text("Refresh")
                    }
                }
                .disabled(isLoadingDiskUsage)
            }

            Text("View and manage Homebrew's disk space usage")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let usage = diskUsage {
                VStack(spacing: 12) {
                    diskUsageRow(
                        label: "Cache",
                        value: usage.formattedCacheSize,
                        icon: "folder.fill",
                        color: .blue
                    )

                    diskUsageRow(
                        label: "Formulae (Cellar)",
                        value: usage.formattedCellarSize,
                        icon: "shippingbox.fill",
                        color: .green
                    )

                    diskUsageRow(
                        label: "Casks",
                        value: usage.formattedCaskroomSize,
                        icon: "app.fill",
                        color: .purple
                    )

                    Divider()

                    diskUsageRow(
                        label: "Total",
                        value: usage.formattedTotalSize,
                        icon: "chart.pie.fill",
                        color: .orange,
                        isTotal: true
                    )
                }
                .padding(12)
                .background(.quaternary.opacity(0.5))
                .cornerRadius(8)

                Button {
                    Task {
                        await clearCache()
                    }
                } label: {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text("Clear Cache")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isClearingCache || (diskUsage?.cacheSize ?? 0) == 0)
            } else if isLoadingDiskUsage {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            }
        }
    }

    private func diskUsageRow(label: String, value: String, icon: String, color: Color, isTotal: Bool = false) -> some View {
        HStack {
            Label {
                Text(label)
                    .fontWeight(isTotal ? .semibold : .regular)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            Spacer()

            Text(value)
                .fontWeight(isTotal ? .semibold : .regular)
                .foregroundStyle(isTotal ? .primary : .secondary)
        }
    }

    // MARK: - Analytics Section

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Analytics", systemImage: "chart.bar")
                .font(.headline)

            Text("Control whether Homebrew sends anonymous analytics")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Toggle(isOn: Binding(
                    get: { analyticsEnabled },
                    set: { newValue in
                        Task {
                            await setAnalytics(enabled: newValue)
                        }
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Send Anonymous Analytics")
                            .font(.body)

                        Text("Helps Homebrew developers understand usage patterns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .disabled(isLoadingAnalytics)

                if isLoadingAnalytics {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(.quaternary.opacity(0.5))
            .cornerRadius(8)
        }
    }

    // MARK: - Actions

    private func runDoctor() async {
        isRunningDoctor = true
        doctorOutput.removeAll()

        let stream = await brewService.runDoctor()
        for await line in stream {
            let lines = line.components(separatedBy: .newlines)
            for outputLine in lines where !outputLine.isEmpty {
                doctorOutput.append(outputLine)
            }
        }

        isRunningDoctor = false
    }

    private func loadDiskUsage() async {
        isLoadingDiskUsage = true

        do {
            diskUsage = try await brewService.getDiskUsage()
        } catch {
            appState.setError(.commandFailed("Failed to load disk usage: \(error.localizedDescription)"))
        }

        isLoadingDiskUsage = false
    }

    private func loadAnalyticsStatus() async {
        isLoadingAnalytics = true

        do {
            analyticsEnabled = try await brewService.getAnalyticsStatus()
        } catch {
            // Analytics might not be available, ignore error
        }

        isLoadingAnalytics = false
    }

    private func setAnalytics(enabled: Bool) async {
        isLoadingAnalytics = true

        do {
            try await brewService.setAnalytics(enabled: enabled)
            analyticsEnabled = enabled
        } catch {
            appState.setError(.commandFailed("Failed to update analytics: \(error.localizedDescription)"))
            // Revert the toggle on error
            analyticsEnabled = !enabled
        }

        isLoadingAnalytics = false
    }

    private func clearCache() async {
        isClearingCache = true
        cacheOutput.removeAll()
        showCacheOutput = true

        let stream = await brewService.clearCache()
        for await line in stream {
            let lines = line.components(separatedBy: .newlines)
            for outputLine in lines where !outputLine.isEmpty {
                cacheOutput.append(outputLine)
            }
        }

        isClearingCache = false

        // Refresh disk usage after clearing cache
        await loadDiskUsage()
    }
}

#Preview {
    let state = AppState()
    state.brewPath = "/opt/homebrew/bin/brew"

    return DiagnosticsView(appState: state)
}
