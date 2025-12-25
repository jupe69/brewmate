import SwiftUI

/// View displaying the installation history
struct HistoryView: View {
    @Bindable var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Installation History")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if !appState.userDataManager.history.isEmpty {
                    Button {
                        showClearConfirmation()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                }
            }
            .padding()

            Divider()

            // History list
            if appState.userDataManager.history.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(appState.userDataManager.history) { entry in
                        HistoryEntryRow(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No History")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Package installation, upgrade, and uninstall actions will appear here")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showClearConfirmation() {
        let alert = NSAlert()
        alert.messageText = "Clear History?"
        alert.informativeText = "This will permanently remove all installation history. This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            appState.userDataManager.clearHistory()
        }
    }
}

/// Row view for a single history entry
struct HistoryEntryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            // Action icon
            ZStack {
                Circle()
                    .fill(actionColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: entry.action.systemImage)
                    .font(.caption)
                    .foregroundStyle(actionColor)
            }

            // Entry details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.packageName)
                        .font(.headline)

                    Image(systemName: entry.isCask ? "app.badge" : "terminal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(entry.action.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("•")
                        .foregroundStyle(.tertiary)

                    Text(entry.formattedTimestamp)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            // Status indicator
            if entry.success {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 8)
        .help(entry.absoluteTimestamp)
    }

    private var actionColor: Color {
        switch entry.action {
        case .install: return .green
        case .uninstall: return .red
        case .upgrade: return .blue
        }
    }
}

#Preview {
    let state = AppState()
    state.userDataManager.addHistoryEntry(action: .install, packageName: "git", isCask: false, success: true)
    state.userDataManager.addHistoryEntry(action: .upgrade, packageName: "node", isCask: false, success: true)
    state.userDataManager.addHistoryEntry(action: .uninstall, packageName: "python", isCask: false, success: false)
    state.userDataManager.addHistoryEntry(action: .install, packageName: "visual-studio-code", isCask: true, success: true)

    return HistoryView(appState: state)
        .frame(width: 700, height: 500)
}
