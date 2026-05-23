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
    @EnvironmentObject var sidebarStore: FileSidebarStore
    @EnvironmentObject var settingsStore: AppSettingsStore

    var body: some View {
        HStack(spacing: 0) {
            if sidebarStore.isVisible {
                FileSidebarView()
                    .environmentObject(sidebarStore)
                    .environmentObject(workspace)
                Divider()
            }

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
        }
        .toolbar { toolbarContent }
        .sheet(isPresented: $snippetStore.showingManager) {
            SnippetsView().environmentObject(snippetStore)
        }
        .sheet(isPresented: $findState.showingResults) {
            FindResultsView()
                .environmentObject(workspace)
                .environmentObject(findState)
                .environmentObject(textViewStore)
        }
        .sheet(isPresented: $findState.showGoToLine) {
            GoToLineView(isPresented: $findState.showGoToLine)
                .environmentObject(textViewStore)
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
            Button(action: { sidebarStore.isVisible.toggle() }) {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            .help(sidebarStore.isVisible ? "Hide sidebar" : "Show file sidebar")

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

            Menu {
                Picker("Width", selection: $previewStore.width) {
                    ForEach(PreviewWidth.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Live reload", isOn: $previewStore.liveReload)
                Toggle("Scroll sync", isOn: $previewStore.scrollSync)
                Toggle("Minimap", isOn: $settingsStore.showMinimap)
                Divider()
                Button("Reload preview") {
                    previewStore.reload(workspace.activeDocument.htmlText)
                }
            } label: {
                Label("Preview", systemImage: "rectangle.righthalf.inset.filled")
            }
            .help("Preview options")
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
    @EnvironmentObject var previewStore: PreviewStore
    @EnvironmentObject var settingsStore: AppSettingsStore

    @State private var showingValidation = false
    @State private var validationIssues: [ValidationIssue] = []

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
            BreadcrumbBarView(document: document)
            HSplitView {
                HStack(spacing: 0) {
                    EditorView(document: document)
                    if settingsStore.showMinimap {
                        Divider()
                        MinimapView(document: document)
                            .frame(width: 80)
                    }
                }
                .frame(minWidth: 300)
                preview
                    .frame(minWidth: 300)
            }
            StatusBar(document: document, onValidate: runValidation)
        }
        .navigationTitle(document.windowTitle)
        .sheet(isPresented: $showingValidation) {
            ValidationPanelView(issues: validationIssues, isPresented: $showingValidation)
        }
    }

    private func runValidation() {
        validationIssues = HTMLValidator.validate(document.htmlText)
        showingValidation = true
    }

    /// The preview, constrained to a device width when one is selected
    /// (centered in the available space), or filling the pane when responsive.
    @ViewBuilder
    private var preview: some View {
        if let width = previewStore.width.points {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                PreviewView(html: document.htmlText)
                    .frame(width: CGFloat(width))
                Spacer(minLength: 0)
            }
            .background(Color(NSColor.windowBackgroundColor))
        } else {
            PreviewView(html: document.htmlText)
        }
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @ObservedObject var document: DocumentModel
    let onValidate: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(document.fileURL?.path ?? "Untitled")
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button(action: onValidate) {
                Label("Validate", systemImage: "checkmark.shield")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Validate HTML")
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
