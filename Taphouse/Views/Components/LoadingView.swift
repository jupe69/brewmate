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

/// A skeleton loading row that mimics package row appearance
struct SkeletonPackageRow: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: CGFloat.random(in: 80...150), height: 14)

                // Description placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: CGFloat.random(in: 150...250), height: 12)
            }

            Spacer()

            // Version placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.15))
                .frame(width: 50, height: 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .opacity(isAnimating ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnimating)
        .onAppear {
            isAnimating = true
        }
    }
}

/// A skeleton loading view for package lists
struct SkeletonListView: View {
    var rowCount: Int = 8

    var body: some View {
        List {
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonPackageRow()
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.inset)
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

            Text("Taphouse requires Homebrew to be installed on your Mac.")
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
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

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

            if let actionTitle = actionTitle, let action = action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
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

    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: error.icon)
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .textSelection(.enabled)

            if let suggestion = error.recoverySuggestion {
                Text(suggestion)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button {
                    copyError()
                } label: {
                    Label(showCopied ? "Copied!" : "Copy Error", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)

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

    private func copyError() {
        let errorText = """
        Error: \(error.localizedDescription)
        Suggestion: \(error.recoverySuggestion ?? "N/A")
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(errorText, forType: .string)

        showCopied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopied = false
        }
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
