import SwiftUI
import UniformTypeIdentifiers

/// View for managing Brewfile export and import
struct BrewfileView: View {
    @Bindable var appState: AppState
    @Environment(\.brewService) private var brewService

    @State private var brewfileContent: String = ""
    @State private var isLoadingBrewfile = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var exportURL: URL?

    var body: some View {
        Group {
            if LicenseManager.shared.isPro {
                brewfileContent_
            } else {
                InlinePaywallView(feature: .brewfile)
            }
        }
        .navigationTitle("Brewfile")
    }

    private var brewfileContent_: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection

                Divider()

                // Preview Section
                previewSection

                Divider()

                // Actions Section
                actionsSection
            }
            .padding(24)
        }
        .task {
            await loadBrewfile()
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.plainText, UTType(filenameExtension: "brewfile") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: BrewfileDocument(content: brewfileContent),
            contentType: .plainText,
            defaultFilename: "Brewfile"
        ) { result in
            handleFileExport(result)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 64, height: 64)

                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Brewfile Management")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Export and import your installed packages")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("A Brewfile is a list of all your installed formulae, casks, and taps. You can use it to restore your setup on a new machine or share your configuration.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
        }
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Brewfile Preview")
                    .font(.headline)

                Spacer()

                Button {
                    Task {
                        await loadBrewfile()
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(isLoadingBrewfile)
            }

            if isLoadingBrewfile {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Generating Brewfile...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else if brewfileContent.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)

                    Text("No packages installed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                ScrollView {
                    Text(brewfileContent)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(minHeight: 200, maxHeight: 400)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Actions")
                .font(.headline)

            VStack(spacing: 12) {
                // Export section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Export")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Button {
                            showFileExporter = true
                        } label: {
                            Label("Export to File", systemImage: "square.and.arrow.up")
                        }
                        .disabled(brewfileContent.isEmpty || isLoadingBrewfile)

                        Button {
                            copyToClipboard()
                        } label: {
                            Label("Copy to Clipboard", systemImage: "doc.on.doc")
                        }
                        .disabled(brewfileContent.isEmpty || isLoadingBrewfile)
                    }

                    Text("Save your current Brewfile to a file or copy it to the clipboard")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // Import section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Import")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack {
                        Button {
                            showFileImporter = true
                        } label: {
                            Label("Import from File", systemImage: "square.and.arrow.down")
                        }
                        .disabled(isImporting || appState.isOperationInProgress)

                        Button {
                            Task {
                                await applyCurrentBrewfile()
                            }
                        } label: {
                            Label("Apply Current Brewfile", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(brewfileContent.isEmpty || isImporting || appState.isOperationInProgress)
                    }

                    Text("Install packages from a Brewfile. This will install missing packages but won't uninstall extras.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .background(.quaternary.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    // MARK: - Actions

    private func loadBrewfile() async {
        isLoadingBrewfile = true

        do {
            brewfileContent = try await brewService.exportBrewfile()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
            brewfileContent = ""
        }

        isLoadingBrewfile = false
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            Task {
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    await importBrewfile(content: content)
                } catch {
                    appState.setError(.commandFailed("Failed to read file: \(error.localizedDescription)"))
                }
            }

        case .failure(let error):
            appState.setError(.commandFailed("Failed to select file: \(error.localizedDescription)"))
        }
    }

    private func handleFileExport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // File was saved successfully
            print("Brewfile exported to: \(url.path)")

        case .failure(let error):
            appState.setError(.commandFailed("Failed to export file: \(error.localizedDescription)"))
        }
    }

    private func importBrewfile(content: String) async {
        isImporting = true
        appState.isOperationInProgress = true
        appState.currentOperation = "Installing packages from Brewfile..."
        appState.clearOperationOutput()

        let stream = await brewService.importBrewfile(content: content)
        for await line in stream {
            appState.appendOperationOutput(line)
        }

        // Refresh package lists after import
        do {
            appState.installedFormulae = try await brewService.getInstalledFormulae()
            appState.installedCasks = try await brewService.getInstalledCasks()
            appState.outdatedPackages = try await brewService.getOutdated()
        } catch {
            appState.setError(.commandFailed(error.localizedDescription))
        }

        appState.isOperationInProgress = false
        isImporting = false
    }

    private func applyCurrentBrewfile() async {
        await importBrewfile(content: brewfileContent)
    }

    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(brewfileContent, forType: .string)
    }
}

// MARK: - Brewfile Document

struct BrewfileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var content: String

    init(content: String = "") {
        self.content = content
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            content = String(decoding: data, as: UTF8.self)
        } else {
            content = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = content.data(using: .utf8) ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    return NavigationStack {
        BrewfileView(appState: state)
    }
    .frame(width: 700, height: 800)
}
