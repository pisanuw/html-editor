import AppKit
import WebKit
import UniformTypeIdentifiers

/// File-producing export actions. The string transforms come from the pure,
/// tested `HTMLExporter`; this layer adds the AppKit save panels and the
/// WebKit PDF rendering that cannot be unit-tested.
enum ExportActions {

    /// Export a complete, standalone HTML document (wrapping a fragment in a
    /// minimal HTML5 skeleton if needed).
    static func exportStandaloneHTML(_ html: String) {
        let document = HTMLExporter.standaloneDocument(html)
        save(text: document, defaultName: HTMLExporter.suggestedFilename(for: html), type: .html)
    }

    /// Export a minified copy of the document.
    static func exportMinifiedHTML(_ html: String) {
        let minified = HTMLExporter.minify(html)
        save(text: minified, defaultName: minifiedName(for: html), type: .html)
    }

    /// Render the live preview to a PDF file.
    static func exportPDF(from webView: WKWebView?, sourceHTML: String) {
        guard let webView else { NSSound.beep(); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = pdfName(for: sourceHTML)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        webView.createPDF(configuration: WKPDFConfiguration()) { result in
            switch result {
            case .success(let data):
                try? data.write(to: url)
            case .failure:
                NSSound.beep()
            }
        }
    }

    /// Export the document converted to Markdown.
    static func exportMarkdown(_ html: String) {
        let markdown = HTMLToMarkdown.convert(html)
        let type = UTType(filenameExtension: "md") ?? .plainText
        save(text: markdown, defaultName: base(for: html) + ".md", type: type)
    }

    /// Render the live preview to a PNG image file.
    static func exportPNG(from webView: WKWebView?, sourceHTML: String) {
        guard let webView else { NSSound.beep(); return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = base(for: sourceHTML) + ".png"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let config = WKSnapshotConfiguration()
        webView.takeSnapshot(with: config) { image, _ in
            guard let image,
                  let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff),
                  let data = rep.representation(using: .png, properties: [:]) else {
                NSSound.beep(); return
            }
            try? data.write(to: url)
        }
    }

    /// Write the HTML to a temp file and open it in the default browser.
    static func openInBrowser(_ html: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLEditorPreview.html")
        try? html.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.open(url)
    }

    /// Print the rendered preview using the live WKWebView.
    static func printPreview(_ webView: WKWebView?) {
        guard let webView else { NSSound.beep(); return }
        let op = webView.printOperation(with: NSPrintInfo.shared)
        op.showsPrintPanel = true
        op.showsProgressPanel = true
        op.run()
    }

    // MARK: - Private

    private static func save(text: String, defaultName: String, type: UTType) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [type]
        panel.nameFieldStringValue = defaultName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func base(for html: String) -> String {
        let name = HTMLExporter.suggestedFilename(for: html)
        return name.hasSuffix(".html") ? String(name.dropLast(5)) : name
    }

    private static func minifiedName(for html: String) -> String { base(for: html) + ".min.html" }
    private static func pdfName(for html: String) -> String { base(for: html) + ".pdf" }
}
