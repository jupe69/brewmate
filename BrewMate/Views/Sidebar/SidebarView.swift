import SwiftUI

/// The sidebar navigation view
struct SidebarView: View {
    @Bindable var appState: AppState

    var body: some View {
        List(selection: $appState.selectedSection) {
            // Main Section
            Section {
                SidebarRow(section: .search, badge: nil)
            }

            Section("Main") {
                SidebarRow(section: .installed, badge: badgeCount(for: .installed))
                SidebarRow(section: .formulae, badge: badgeCount(for: .formulae))
                SidebarRow(section: .casks, badge: badgeCount(for: .casks))
                SidebarRow(
                    section: .updates,
                    badge: appState.outdatedCount > 0 ? appState.outdatedCount : nil
                )
            }

            // Organization Section
            Section("Organization") {
                SidebarRow(section: .favorites, badge: nil)
                SidebarRow(section: .pinned, badge: nil)
            }

            // Management Section
            Section("Management") {
                SidebarRow(section: .taps, badge: badgeCount(for: .taps))
                SidebarRow(section: .services, badge: nil)
                SidebarRow(section: .brewfile, badge: nil)
            }

            // Maintenance Section
            Section("Maintenance") {
                SidebarRow(section: .diagnostics, badge: nil)
                SidebarRow(section: .cleanup, badge: nil)
                SidebarRow(section: .quarantine, badge: nil)
                SidebarRow(section: .history, badge: nil)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }

    private func badgeCount(for section: SidebarSection) -> Int? {
        switch section {
        case .formulae:
            return appState.installedFormulae.isEmpty ? nil : appState.installedFormulae.count
        case .casks:
            return appState.installedCasks.isEmpty ? nil : appState.installedCasks.count
        case .installed:
            let total = appState.installedFormulae.count + appState.installedCasks.count
            return total > 0 ? total : nil
        case .taps:
            return appState.taps.isEmpty ? nil : appState.taps.count
        default:
            return nil
        }
    }
}

/// A single row in the sidebar
struct SidebarRow: View {
    let section: SidebarSection
    let badge: Int?

    var body: some View {
        Label {
            HStack {
                Text(section.rawValue)

                Spacer()

                if let badge, badge > 0 {
                    Text("\(badge)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
        } icon: {
            Image(systemName: section.systemImage)
        }
        .tag(section)
    }
}

#Preview {
    let state = AppState()
    state.installedFormulae = [
        Formula(name: "git", fullName: "git", version: "2.43.0", description: nil, homepage: nil, installedAsDependency: false, dependencies: [], installedOn: nil)
    ]
    return NavigationSplitView {
        SidebarView(appState: state)
    } content: {
        Text("Content")
    } detail: {
        Text("Detail")
    }
}
