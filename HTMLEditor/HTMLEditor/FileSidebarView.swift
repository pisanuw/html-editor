import SwiftUI
import AppKit
import Combine

/// Tracks the currently open project folder and its file listing.
final class FileSidebarStore: ObservableObject {
    @Published var projectURL: URL?
    @Published var files: [URL] = []
    @Published var isVisible: Bool = false

    private let supportedExtensions: Set<String> = ["html", "htm", "css", "js", "json", "md", "txt", "svg"]

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Folder"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        projectURL = url
        reload()
        isVisible = true
    }

    func reload() {
        guard let root = projectURL else { files = []; return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .nameKey],
            options: [.skipsHiddenFiles]
        ) else { files = []; return }
        files = items
            .filter { supportedExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}

/// A sidebar showing the files in the project folder. Clicking a file opens it
/// in a new tab. Includes a folder picker and a refresh button.
struct FileSidebarView: View {
    @EnvironmentObject var sidebarStore: FileSidebarStore
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(sidebarStore.projectURL?.lastPathComponent ?? "Project")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(action: sidebarStore.chooseFolder) {
                    Image(systemName: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .help("Open folder")

                Button(action: sidebarStore.reload) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider(), alignment: .bottom)

            if sidebarStore.files.isEmpty {
                Spacer()
                if sidebarStore.projectURL == nil {
                    Button("Open Folder…", action: sidebarStore.chooseFolder)
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                } else {
                    Text("No supported files")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sidebarStore.files, id: \.self) { url in
                            SidebarFileRow(url: url)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 280)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct SidebarFileRow: View {
    let url: URL
    @EnvironmentObject var workspace: Workspace
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon(for: url.pathExtension))
                .font(.system(size: 11))
                .foregroundColor(iconColor(for: url.pathExtension))
                .frame(width: 14)
            Text(url.lastPathComponent)
                .font(.system(size: 12))
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(hovering ? Color.accentColor.opacity(0.12) : Color.clear)
        .onHover { hovering = $0 }
        .onTapGesture { workspace.open(url: url) }
        .help(url.path)
    }

    private func icon(for ext: String) -> String {
        switch ext.lowercased() {
        case "html", "htm": return "doc.richtext"
        case "css":         return "paintbrush"
        case "js":          return "chevron.left.forwardslash.chevron.right"
        case "json":        return "curlybraces"
        case "md":          return "doc.text"
        case "svg":         return "square.on.square"
        default:            return "doc"
        }
    }

    private func iconColor(for ext: String) -> Color {
        switch ext.lowercased() {
        case "html", "htm": return .orange
        case "css":         return .blue
        case "js":          return .yellow
        case "json":        return .green
        default:            return .secondary
        }
    }
}
