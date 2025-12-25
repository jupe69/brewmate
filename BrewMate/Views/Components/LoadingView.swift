import SwiftUI

/// A loading indicator with optional message
struct LoadingView: View {
    var message: String?

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// An inline loading indicator for list rows
struct InlineLoadingView: View {
    var message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
}

/// A view shown when Homebrew is not installed
struct BrewNotInstalledView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Homebrew Not Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("BrewMate requires Homebrew to be installed on your Mac.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Link(destination: URL(string: "https://brew.sh")!) {
                HStack {
                    Text("Install Homebrew")
                    Image(systemName: "arrow.up.right")
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Empty state view for when there are no packages
struct EmptyStateView: View {
    var title: String
    var message: String
    var systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error view with retry option
struct ErrorView: View {
    var error: AppError
    var onRetry: (() -> Void)?
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 12) {
                if let onDismiss {
                    Button("Dismiss") {
                        onDismiss()
                    }
                }

                if let onRetry {
                    Button("Retry") {
                        onRetry()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.top, 8)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// A toast notification view
struct ToastView: View {
    var message: String
    var type: ToastType

    enum ToastType {
        case success
        case error
        case info

        var systemImage: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.systemImage)
                .foregroundStyle(type.color)

            Text(message)
                .font(.subheadline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 4)
    }
}

/// Operation output view showing streaming command output
struct OperationOutputView: View {
    var title: String
    var output: [String]
    var isRunning: Bool
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                if isRunning {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(title)
                    .font(.headline)

                Spacer()

                if isRunning {
                    Text("Running...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button(isRunning ? "Cancel" : "Done") {
                    onDismiss()
                }
                .keyboardShortcut(isRunning ? .cancelAction : .defaultAction)
            }
            .padding()
            .background(.bar)

            Divider()

            // Output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if output.isEmpty && isRunning {
                            Text("Starting...")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .id(-1)
                        }
                        ForEach(Array(output.enumerated()), id: \.offset) { index, line in
                            Text(line.strippingANSICodes)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: output.count) { _, _ in
                    if let lastIndex = output.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}

#Preview("Loading") {
    LoadingView(message: "Loading packages...")
}

#Preview("Not Installed") {
    BrewNotInstalledView()
}

#Preview("Empty State") {
    EmptyStateView(
        title: "No Packages",
        message: "You don't have any formulae installed yet.",
        systemImage: "shippingbox"
    )
}

#Preview("Toast") {
    VStack(spacing: 20) {
        ToastView(message: "Package installed successfully", type: .success)
        ToastView(message: "Failed to install package", type: .error)
        ToastView(message: "Updating package list...", type: .info)
    }
    .padding()
}
