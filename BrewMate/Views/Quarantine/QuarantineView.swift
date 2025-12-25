import SwiftUI

/// View for managing quarantined applications
struct QuarantineView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService
    @State private var quarantinedApps: [QuarantinedApp] = []
    @State private var isLoading = false
    @State private var showingRemoveConfirmation = false
    @State private var appToRemoveQuarantine: QuarantinedApp?

    var body: some View {
        Group {
            if LicenseManager.shared.isPro {
                quarantineContent
            } else {
                InlinePaywallView(feature: .quarantine)
            }
        }
    }

    private var quarantineContent: some View {
        VStack(spacing: 0) {
            // Info banner
            infoBanner

            Divider()

            // Main content
            if isLoading {
                LoadingView(message: "Scanning for quarantined apps...")
            } else if quarantinedApps.isEmpty {
                emptyStateView
            } else {
                quarantinedAppsList
            }
        }
        .navigationTitle("Quarantine Management")
        .task {
            await loadQuarantinedApps()
        }
        .refreshable {
            await loadQuarantinedApps()
        }
        .confirmationDialog(
            "Remove Quarantine Attribute?",
            isPresented: $showingRemoveConfirmation,
            presenting: appToRemoveQuarantine,
            actions: { app in
                Button("Remove Quarantine", role: .destructive) {
                    Task {
                        await removeQuarantine(for: app)
                    }
                }
                Button("Cancel", role: .cancel) {}
            },
            message: { app in
                Text("Are you sure you want to remove the quarantine attribute from \(app.displayName)?\n\nThis will disable macOS Gatekeeper protection for this application. Only do this if you trust the source of this application.")
            }
        )
    }

    // MARK: - Subviews

    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("About Quarantine")
                        .font(.headline)

                    Text("macOS automatically quarantines applications downloaded from the internet as a security measure. This is part of Gatekeeper protection.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Security Information:")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Quarantine prevents unverified apps from running", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Only remove quarantine from apps you trust", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)

                    Label("Apps from Mac App Store are never quarantined", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.bar)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("No Quarantined Apps")
                .font(.title2)
                .fontWeight(.semibold)

            Text("All your applications are clear of quarantine attributes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var quarantinedAppsList: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("\(quarantinedApps.count) quarantined app\(quarantinedApps.count == 1 ? "" : "s") found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Refresh") {
                    Task {
                        await loadQuarantinedApps()
                    }
                }
                .disabled(isLoading)
            }
            .padding()
            .background(.bar)

            Divider()

            // List
            List(quarantinedApps) { app in
                QuarantineAppRow(app: app) {
                    appToRemoveQuarantine = app
                    showingRemoveConfirmation = true
                }
            }
            .listStyle(.inset)
        }
    }

    // MARK: - Actions

    private func loadQuarantinedApps() async {
        isLoading = true

        do {
            quarantinedApps = try await brewService.getQuarantinedApps()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isLoading = false
    }

    private func removeQuarantine(for app: QuarantinedApp) async {
        do {
            try await brewService.removeQuarantine(appPath: app.path)

            // Refresh the list
            await loadQuarantinedApps()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }
    }
}

// MARK: - Supporting Views

struct QuarantineAppRow: View {
    let app: QuarantinedApp
    let onRemoveQuarantine: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // App icon placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.orange.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "app.badge")
                    .font(.system(size: 24))
                    .foregroundStyle(.orange)
            }

            // App info
            VStack(alignment: .leading, spacing: 4) {
                Text(app.displayName)
                    .font(.headline)

                if let caskName = app.caskName {
                    Label("Installed via Homebrew: \(caskName)", systemImage: "cube.box.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Not installed via Homebrew", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Text(app.path)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let date = app.quarantineDate {
                    Label("Quarantined: \(date.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Remove button
            Button {
                onRemoveQuarantine()
            } label: {
                Label("Remove Quarantine", systemImage: "shield.slash")
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    let state = AppState()
    return NavigationStack {
        QuarantineView(appState: state)
    }
    .frame(width: 700, height: 600)
}
