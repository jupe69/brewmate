import SwiftUI

/// View showing the dependency tree and dependents for a package
struct DependencyTreeView: View {
    let package: Package
    @Environment(\.brewService) private var brewService

    @State private var dependencyTree: DependencyTree?
    @State private var dependents: [String] = []
    @State private var isLoadingDependencies = false
    @State private var isLoadingDependents = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Dependencies Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Dependencies", systemImage: "arrow.down.circle")
                        .font(.headline)
                        .foregroundStyle(.blue)

                    Spacer()

                    if isLoadingDependencies {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let error = error, dependencyTree == nil {
                    errorView(message: error)
                } else if let tree = dependencyTree {
                    if tree.dependencies.isEmpty {
                        emptyStateView(message: "No dependencies", icon: "checkmark.circle")
                    } else {
                        dependencyTreeContent(tree)
                    }
                } else if !isLoadingDependencies {
                    emptyStateView(message: "No dependency information", icon: "info.circle")
                }
            }

            Divider()

            // Dependents Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Dependents", systemImage: "arrow.up.circle")
                        .font(.headline)
                        .foregroundStyle(.orange)

                    Spacer()

                    if isLoadingDependents {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if dependents.isEmpty && !isLoadingDependents {
                    emptyStateView(message: "No other packages depend on this", icon: "checkmark.circle")
                } else {
                    dependentsContent
                }
            }
        }
        .padding(20)
        .task {
            await loadDependencyInfo()
        }
    }

    // MARK: - Subviews

    private func dependencyTreeContent(_ tree: DependencyTree) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(package.name) requires:")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(tree.dependencies) { node in
                        DependencyNodeView(node: node, level: 0)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dependentsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !dependents.isEmpty {
                Text("These packages depend on \(package.name):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(dependents, id: \.self) { dependent in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)

                            Text(dependent)
                                .font(.subheadline)
                                .foregroundStyle(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding(12)
        .background(Color.orange.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func emptyStateView(message: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.secondary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func errorView(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func loadDependencyInfo() async {
        // Only load dependencies for formulae, casks don't have dependency trees
        guard package.isFormula else {
            error = "Dependency information is only available for formulae"
            return
        }

        isLoadingDependencies = true
        isLoadingDependents = true

        // Load dependency tree
        do {
            dependencyTree = try await brewService.getDependencyTree(packageName: package.packageName)
        } catch {
            self.error = "Failed to load dependencies: \(error.localizedDescription)"
        }

        isLoadingDependencies = false

        // Load dependents
        do {
            dependents = try await brewService.getDependents(packageName: package.packageName)
        } catch {
            // Don't show error for dependents, just leave empty
            dependents = []
        }

        isLoadingDependents = false
    }
}

// MARK: - Dependency Node View

struct DependencyNodeView: View {
    let node: DependencyNode
    let level: Int
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                // Indentation
                if level > 0 {
                    ForEach(0..<level, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.secondary.opacity(0.2))
                            .frame(width: 2)
                            .padding(.leading, 8)
                    }
                }

                // Expand/collapse button if has children
                if !node.children.isEmpty {
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Spacer for alignment
                    Color.clear.frame(width: 12, height: 12)
                }

                // Dependency icon
                Image(systemName: "cube.box")
                    .font(.caption)
                    .foregroundStyle(.blue)

                // Package name
                Text(node.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer()

                // Children count badge
                if !node.children.isEmpty {
                    Text("\(node.children.count)")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(level % 2 == 0 ? Color.clear : Color.secondary.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 4))

            // Children (if expanded)
            if isExpanded && !node.children.isEmpty {
                ForEach(node.children) { child in
                    DependencyNodeView(node: child, level: level + 1)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let state = AppState()
    let formula = Formula(
        name: "git",
        fullName: "git",
        version: "2.43.0",
        description: "Distributed revision control system",
        homepage: "https://git-scm.com",
        installedAsDependency: false,
        dependencies: ["gettext", "pcre2"],
        installedOn: Date()
    )

    return DependencyTreeView(package: .formula(formula))
        .frame(width: 500, height: 600)
}
