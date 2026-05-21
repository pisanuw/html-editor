import SwiftUI

struct ContentView: View {
    @EnvironmentObject var document: DocumentModel
    @EnvironmentObject var textViewStore: TextViewStore

    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                EditorView(text: $document.htmlText)
                    .frame(minWidth: 300)
                PreviewView(html: document.htmlText)
                    .frame(minWidth: 300)
            }
            StatusBar()
        }
        .navigationTitle(document.windowTitle)
        .toolbar { toolbarContent }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        // File actions (left side)
        ToolbarItemGroup(placement: .navigation) {
            Button(action: document.newDocument) {
                Label("New", systemImage: "doc")
            }
            .help("New document")

            Button(action: document.openDocument) {
                Label("Open", systemImage: "folder")
            }
            .help("Open HTML file")

            Button(action: document.saveDocument) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .help("Save")
        }

        // Formatting (right side / primary)
        ToolbarItemGroup(placement: .primaryAction) {
            // Headings
            Button("H1") { wrap("<h1>", "</h1>") }
                .help("Heading 1")
            Button("H2") { wrap("<h2>", "</h2>") }
                .help("Heading 2")
            Button("H3") { wrap("<h3>", "</h3>") }
                .help("Heading 3")

            Divider()

            // Inline formatting
            Button(action: { wrap("<strong>", "</strong>") }) {
                Text("B").bold()
            }
            .help("Bold  <strong>")

            Button(action: { wrap("<em>", "</em>") }) {
                Text("I").italic()
            }
            .help("Italic  <em>")

            Button(action: { wrap("<code>", "</code>") }) {
                Image(systemName: "curlybraces")
            }
            .help("Inline code  <code>")

            Divider()

            // Block / structural
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

            Button(action: { wrap("<p>", "</p>") }) {
                Image(systemName: "paragraph")
            }
            .help("Paragraph  <p>")
        }
    }

    private func wrap(_ before: String, _ after: String, placeholder: String = "text") {
        textViewStore.wrapSelection(before: before, after: after, placeholder: placeholder)
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @EnvironmentObject var document: DocumentModel

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
