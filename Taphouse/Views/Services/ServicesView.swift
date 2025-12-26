import SwiftUI

/// View for managing Homebrew services with status overview and auto-refresh
struct ServicesView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var isLoading = false
    @State private var error: String?
    @State private var controllingService: String?

    // Auto-refresh settings
    @AppStorage("servicesAutoRefresh") private var autoRefreshEnabled = false
    @AppStorage("servicesRefreshInterval") private var refreshInterval: Double = 30

    // Timer for auto-refresh
    @State private var refreshTimer: Timer?

    private let refreshIntervals: [(String, Double)] = [
        ("10 seconds", 10),
        ("30 seconds", 30),
        ("1 minute", 60),
        ("5 minutes", 300)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Summary header
            summaryHeader

            Divider()

            // Main content
            if isLoading && appState.services.isEmpty {
                LoadingView(message: "Loading services...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                EmptyStateView(
                    title: "Failed to Load",
                    message: error,
                    systemImage: "exclamationmark.triangle"
                )
            } else if appState.services.isEmpty {
                EmptyStateView(
                    title: "No Services",
                    message: "You don't have any Homebrew services installed.\n\nServices are background processes managed by Homebrew, like databases or web servers.",
                    systemImage: "gearshape.2"
                )
            } else {
                servicesList
            }
        }
        .navigationTitle("Services")
        .task {
            await loadServices()
        }
        .onAppear {
            setupAutoRefresh()
        }
        .onDisappear {
            stopAutoRefresh()
        }
        .onChange(of: autoRefreshEnabled) { _, enabled in
            if enabled {
                setupAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
        .onChange(of: refreshInterval) { _, _ in
            if autoRefreshEnabled {
                setupAutoRefresh()
            }
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        HStack(spacing: 24) {
            // Status counts
            HStack(spacing: 16) {
                StatusBadge(
                    count: runningCount,
                    label: "Running",
                    color: .green,
                    systemImage: "play.circle.fill"
                )

                StatusBadge(
                    count: stoppedCount,
                    label: "Stopped",
                    color: .secondary,
                    systemImage: "stop.circle.fill"
                )

                if errorCount > 0 {
                    StatusBadge(
                        count: errorCount,
                        label: "Error",
                        color: .red,
                        systemImage: "exclamationmark.circle.fill"
                    )
                }
            }

            Spacer()

            // Auto-refresh controls
            HStack(spacing: 12) {
                Toggle("Auto-refresh", isOn: $autoRefreshEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                if autoRefreshEnabled {
                    Picker("Interval", selection: $refreshInterval) {
                        ForEach(refreshIntervals, id: \.1) { option in
                            Text(option.0).tag(option.1)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }

                Button {
                    Task { await loadServices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .help("Refresh now")
            }
        }
        .padding()
        .background(.bar)
    }

    // MARK: - Services List

    private var servicesList: some View {
        List {
            // Running services section
            if !runningServices.isEmpty {
                Section {
                    ForEach(runningServices) { service in
                        ServiceCard(
                            service: service,
                            isControlling: controllingService == service.name,
                            onAction: { action in
                                Task { await controlService(service.name, action: action) }
                            }
                        )
                    }
                } header: {
                    Label("Running", systemImage: "play.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Stopped services section
            if !stoppedServices.isEmpty {
                Section {
                    ForEach(stoppedServices) { service in
                        ServiceCard(
                            service: service,
                            isControlling: controllingService == service.name,
                            onAction: { action in
                                Task { await controlService(service.name, action: action) }
                            }
                        )
                    }
                } header: {
                    Label("Stopped", systemImage: "stop.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }

            // Error services section
            if !errorServices.isEmpty {
                Section {
                    ForEach(errorServices) { service in
                        ServiceCard(
                            service: service,
                            isControlling: controllingService == service.name,
                            onAction: { action in
                                Task { await controlService(service.name, action: action) }
                            }
                        )
                    }
                } header: {
                    Label("Error", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Computed Properties

    private var runningServices: [BrewServiceInfo] {
        appState.services.filter { $0.status.isActive }
    }

    private var stoppedServices: [BrewServiceInfo] {
        appState.services.filter { $0.status == .stopped || $0.status == .none }
    }

    private var errorServices: [BrewServiceInfo] {
        appState.services.filter { $0.status == .error || $0.status == .unknown }
    }

    private var runningCount: Int { runningServices.count }
    private var stoppedCount: Int { stoppedServices.count }
    private var errorCount: Int { errorServices.count }

    // MARK: - Actions

    private func loadServices() async {
        isLoading = true
        error = nil

        do {
            appState.services = try await brewService.getServices()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func controlService(_ name: String, action: ServiceAction) async {
        controllingService = name

        do {
            try await brewService.controlService(name: name, action: action)
            // Small delay to let the service status change
            try? await Task.sleep(for: .milliseconds(500))
            await loadServices()
        } catch {
            appState.setError(.commandFailed("Failed to \(action.rawValue) \(name): \(error.localizedDescription)"))
        }

        controllingService = nil
    }

    // MARK: - Auto-refresh

    private func setupAutoRefresh() {
        stopAutoRefresh()

        guard autoRefreshEnabled else { return }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task { @MainActor in
                await loadServices()
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let count: Int
    let label: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.semibold)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ServiceCard: View {
    let service: BrewServiceInfo
    let isControlling: Bool
    let onAction: (ServiceAction) -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Status indicator with icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                if isControlling {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: statusIcon)
                        .font(.title3)
                        .foregroundStyle(statusColor)
                }
            }

            // Service info
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(service.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .foregroundStyle(statusColor)
                        .clipShape(Capsule())

                    if let user = service.user {
                        Text("User: \(user)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let exitCode = service.exitCode, exitCode != 0 {
                        Text("Exit: \(exitCode)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }

            Spacer()

            // Action buttons
            if !isControlling {
                HStack(spacing: 8) {
                    if service.status.isActive {
                        Button {
                            onAction(.restart)
                        } label: {
                            Label("Restart", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            onAction(.stop)
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(.red)
                    } else {
                        Button {
                            onAction(.start)
                        } label: {
                            Label("Start", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .contextMenu {
            if service.status.isActive {
                Button {
                    onAction(.stop)
                } label: {
                    Label("Stop Service", systemImage: "stop.fill")
                }

                Button {
                    onAction(.restart)
                } label: {
                    Label("Restart Service", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    onAction(.start)
                } label: {
                    Label("Start Service", systemImage: "play.fill")
                }
            }

            Divider()

            if let file = service.file {
                Button {
                    NSWorkspace.shared.selectFile(file, inFileViewerRootedAtPath: "")
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }
        }
    }

    private var statusColor: Color {
        switch service.status {
        case .running, .scheduled:
            return .green
        case .stopped, .none:
            return .secondary
        case .error:
            return .red
        case .unknown:
            return .orange
        }
    }

    private var statusIcon: String {
        switch service.status {
        case .running:
            return "play.circle.fill"
        case .scheduled:
            return "clock.fill"
        case .stopped, .none:
            return "stop.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
}

#Preview {
    ServicesView(appState: AppState())
}
