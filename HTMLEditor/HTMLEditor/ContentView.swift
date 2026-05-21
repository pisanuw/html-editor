import SwiftUI
import UniformTypeIdentifiers

/// Top-level layout: the tab strip, an optional find bar, and the editor /
/// preview pane for the active document.
struct ContentView: View {
    @EnvironmentObject var workspace: Workspace
    @EnvironmentObject var textViewStore: TextViewStore
    @EnvironmentObject var findState: FindState
    @EnvironmentObject var previewStore: PreviewStore
    @EnvironmentObject var snippetStore: SnippetStore

    var body: some View {
        VStack(spacing: 0) {
            TabBarView()

            if findState.isVisible {
                FindBarView()
            }

            // Keyed by the active id so the editor's NSTextView is rebuilt for
            // each tab; `DocumentPane` observes the document so the preview and
            // status bar track its text and cursor.
            DocumentPane(document: workspace.activeDocument)
                .id(workspace.activeID)
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $snippetStore.showingManager) {
            SnippetsView().environmentObject(snippetStore)
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            for provider in providers {
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    let ext = url.pathExtension.lowercased()
                    guard ext == "html" || ext == "htm" else { return }
                    DispatchQueue.main.async { workspace.open(url: url) }
                }
            }
            return true
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button(action: workspace.newTab) {
                Label("New", systemImage: "doc")
            }
            .help("New tab")

            Button(action: workspace.openInNewTab) {
                Label("Open", systemImage: "folder")
            }
            .help("Open HTML file in a new tab")

            Button(action: { workspace.activeDocument.saveDocument() }) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button("H1") { wrap("<h1>", "</h1>") }.help("Heading 1")
            Button("H2") { wrap("<h2>", "</h2>") }.help("Heading 2")
            Button("H3") { wrap("<h3>", "</h3>") }.help("Heading 3")

            Divider()

            Button(action: { wrap("<strong>", "</strong>") }) { Text("B").bold() }
                .help("Bold  <strong>")
            Button(action: { wrap("<em>", "</em>") }) { Text("I").italic() }
                .help("Italic  <em>")
            Button(action: { wrap("<code>", "</code>") }) { Image(systemName: "curlybraces") }
                .help("Inline code  <code>")

            Divider()

            Button(action: { wrap("<a href=\"\">", "</a>", placeholder: "link text") }) {
                Image(systemName: "link")
            }
            .help("Hyperlink  <a>")
            Button(action: { textViewStore.insertSnippet("<img src=\"\" alt=\"\">") }) {
                Image(systemName: "photo")
            }
            .help("Image  <img>")
            Button(action: { textViewStore.insertSnippet("<ul>\n  <li>Item</li>\n</ul>") }) {
                Image(systemName: "list.bullet")
            }
            .help("Unordered list  <ul>")
            Button(action: { textViewStore.insertSnippet("<ol>\n  <li>Item</li>\n</ol>") }) {
                Image(systemName: "list.number")
            }
            .help("Ordered list  <ol>")
            Button(action: { wrap("<p>", "</p>") }) { Image(systemName: "paragraph") }
                .help("Paragraph  <p>")

            Divider()

            Button(action: formatDocument) {
                Image(systemName: "wand.and.stars")
            }
            .help("Reformat document  (⌥⌘F)")

            Menu {
                Button("Standalone HTML…") {
                    ExportActions.exportStandaloneHTML(workspace.activeDocument.htmlText)
                }
                Button("Minified HTML…") {
                    ExportActions.exportMinifiedHTML(workspace.activeDocument.htmlText)
                }
                Button("PDF…") {
                    ExportActions.exportPDF(from: previewStore.webView,
                                            sourceHTML: workspace.activeDocument.htmlText)
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .help("Export")
        }
    }

    // MARK: - Actions

    private func wrap(_ before: String, _ after: String, placeholder: String = "text") {
        textViewStore.wrapSelection(before: before, after: after, placeholder: placeholder)
    }

    private func formatDocument() {
        textViewStore.replaceAll(with: HTMLFormatter.prettify(textViewStore.currentText))
    }
}

// MARK: - Document Pane

/// Editor + preview + status bar for a single document. Observes the document
/// directly so SwiftUI refreshes the preview and cursor readout as it changes.
private struct DocumentPane: View {
    @ObservedObject var document: DocumentModel

    var body: some View {
        VStack(spacing: 0) {
            if document.externalChangePending {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This file changed on disk.")
                    Spacer()
                    Button("Reload") { document.reloadFromDisk() }
                    Button("Ignore") { document.ignoreExternalChange() }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(NSColor.windowBackgroundColor))
                .overlay(Divider(), alignment: .bottom)
            }
            HSplitView {
                EditorView(document: document)
                    .frame(minWidth: 300)
                PreviewView(html: document.htmlText)
                    .frame(minWidth: 300)
            }
            StatusBar(document: document)
        }
        .navigationTitle(document.windowTitle)
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @ObservedObject var document: DocumentModel

    var body: some View {
        HStack(spacing: 16) {
            Text(document.fileURL?.path ?? "Untitled")
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Text("Ln \(document.cursorLine)  Col \(document.cursorColumn)")
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(Divider(), alignment: .top)
        .font(.system(size: 11))
    }
}
