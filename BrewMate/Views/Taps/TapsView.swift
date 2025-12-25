import SwiftUI

/// View for managing Homebrew taps (repositories)
struct TapsView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var isLoading = false
    @State private var selectedTap: TapInfo?
    @State private var showAddTap = false
    @State private var newTapName = ""
    @State private var isAddingTap = false
    @State private var showRemoveConfirmation = false
    @State private var tapToRemove: TapInfo?

    var body: some View {
        Group {
            if LicenseManager.shared.isPro {
                tapsContent
            } else {
                InlinePaywallView(feature: .taps)
            }
        }
    }

    private var tapsContent: some View {
        HSplitView {
            // Taps list
            VStack(spacing: 0) {
                toolbar
                Divider()
                tapsList
            }
            .frame(minWidth: 300)

            // Detail pane
            if let selected = selectedTap {
                TapDetailView(tap: selected, onRemove: {
                    tapToRemove = selected
                    showRemoveConfirmation = true
                })
            } else {
                noSelectionView
            }
        }
        .navigationTitle("Taps")
        .task {
            await loadTaps()
        }
        .sheet(isPresented: $showAddTap) {
            AddTapSheet(
                tapName: $newTapName,
                isAdding: $isAddingTap,
                onAdd: { await addTap() },
                onCancel: { showAddTap = false }
            )
        }
        .alert("Remove Tap", isPresented: $showRemoveConfirmation, presenting: tapToRemove) { tap in
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { await removeTap(tap) }
            }
        } message: { tap in
            Text("Are you sure you want to remove '\(tap.name)'? This will remove the tap and all its formulas and casks.")
        }
    }

    private var toolbar: some View {
        HStack {
            Text("Repositories")
                .font(.headline)

            Spacer()

            Button {
                showAddTap = true
            } label: {
                Image(systemName: "plus")
            }
            .help("Add tap")
            .disabled(isLoading || appState.isLoading)

            Button {
                Task { await loadTaps() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Refresh")
            .disabled(isLoading || appState.isLoading)
        }
        .padding(12)
    }

    private var tapsList: some View {
        Group {
            if isLoading {
                LoadingView(message: "Loading taps...")
            } else if appState.taps.isEmpty {
                EmptyStateView(
                    title: "No Taps",
                    message: "You don't have any additional taps installed.",
                    systemImage: "spigot"
                )
            } else {
                List(selection: $selectedTap) {
                    ForEach(appState.taps) { tap in
                        TapRow(tap: tap)
                            .tag(tap)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var noSelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "spigot")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Select a tap")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Choose a tap from the list to view its details")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadTaps() async {
        isLoading = true

        do {
            appState.taps = try await brewService.getTaps()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isLoading = false
    }

    private func addTap() async {
        guard !newTapName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isAddingTap = true

        do {
            try await brewService.addTap(name: newTapName)
            await loadTaps()
            showAddTap = false
            newTapName = ""
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        isAddingTap = false
    }

    private func removeTap(_ tap: TapInfo) async {
        appState.isLoading = true

        do {
            try await brewService.removeTap(name: tap.name)
            await loadTaps()
            if selectedTap?.id == tap.id {
                selectedTap = nil
            }
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isLoading = false
    }
}

/// Row for displaying a tap in the list
struct TapRow: View {
    let tap: TapInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: tap.isOfficial ? "checkmark.seal.fill" : "spigot")
                    .foregroundStyle(tap.isOfficial ? .blue : .secondary)
                    .frame(width: 20)

                Text(tap.name)
                    .lineLimit(1)
            }

            if tap.totalCount > 0 {
                HStack(spacing: 12) {
                    if tap.formulaCount > 0 {
                        Label("\(tap.formulaCount)", systemImage: "terminal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if tap.caskCount > 0 {
                        Label("\(tap.caskCount)", systemImage: "app.badge")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

/// Detail view for a selected tap
struct TapDetailView: View {
    let tap: TapInfo
    let onRemove: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(tap.isOfficial ? Color.blue.opacity(0.15) : Color.secondary.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Image(systemName: tap.isOfficial ? "checkmark.seal.fill" : "spigot")
                            .font(.system(size: 28))
                            .foregroundStyle(tap.isOfficial ? .blue : .secondary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(tap.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if tap.isOfficial {
                            Label("Official", systemImage: "checkmark.seal.fill")
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }

                    Spacer()
                }

                Divider()

                // Stats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Statistics")
                        .font(.headline)

                    HStack(spacing: 24) {
                        StatItem(title: "Formulae", value: "\(tap.formulaCount)", systemImage: "terminal")
                        StatItem(title: "Casks", value: "\(tap.caskCount)", systemImage: "app.badge")
                        if tap.commandCount > 0 {
                            StatItem(title: "Commands", value: "\(tap.commandCount)", systemImage: "terminal.fill")
                        }
                    }
                }

                // Repository Info
                if let remote = tap.remote, let url = URL(string: remote) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repository")
                            .font(.headline)
                        Button {
                            openURL(url)
                        } label: {
                            Text(remote)
                                .foregroundStyle(.blue)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Path
                VStack(alignment: .leading, spacing: 8) {
                    Text("Path")
                        .font(.headline)
                    Text(tap.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                // Remove button (only for non-core taps)
                if !tap.isOfficial {
                    Divider()

                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Label("Remove Tap", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
        }
    }
}

/// Statistics item view
struct StatItem: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

/// Sheet for adding a new tap
struct AddTapSheet: View {
    @Binding var tapName: String
    @Binding var isAdding: Bool
    let onAdd: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Add Tap")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter the name of the tap you want to add (e.g., homebrew/cask-fonts)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            TextField("user/repo", text: $tapName)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    if !tapName.isEmpty && !isAdding {
                        Task { await onAdd() }
                    }
                }

            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button {
                    Task { await onAdd() }
                } label: {
                    if isAdding {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Add")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(tapName.isEmpty || isAdding)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

#Preview {
    TapsView(appState: AppState())
}
