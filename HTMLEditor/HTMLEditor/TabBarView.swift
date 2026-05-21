import SwiftUI

/// A horizontal strip of document tabs with a trailing "new tab" button.
struct TabBarView: View {
    @EnvironmentObject var workspace: Workspace

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(workspace.documents) { document in
                        TabItemView(document: document,
                                    isActive: document.id == workspace.activeID,
                                    canClose: workspace.documents.count > 1,
                                    onSelect: { workspace.select(document.id) },
                                    onClose: { workspace.close(document.id) })
                        Divider().frame(height: 18)
                    }
                }
            }

            Button(action: workspace.newTab) {
                Image(systemName: "plus")
                    .frame(width: 28, height: 26)
            }
            .buttonStyle(.borderless)
            .help("New tab")
        }
        .frame(height: 30)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .bottom)
    }
}

private struct TabItemView: View {
    @ObservedObject var document: DocumentModel
    let isActive: Bool
    let canClose: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            if canClose && hovering {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                }
                .buttonStyle(.borderless)
                .help("Close tab")
            } else {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Text(document.windowTitle)
                .lineLimit(1)
                .font(.system(size: 12))
                .foregroundColor(isActive ? .primary : .secondary)
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(isActive ? Color(NSColor.controlBackgroundColor) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering = $0 }
    }
}
