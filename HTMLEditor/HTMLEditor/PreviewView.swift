import SwiftUI
import WebKit
import Combine

/// Exposes the live preview `WKWebView` so document actions (e.g. Export to PDF)
/// can render the currently displayed page.
final class PreviewStore: ObservableObject {
    weak var webView: WKWebView?
}

struct PreviewView: NSViewRepresentable {
    var html: String
    @EnvironmentObject var previewStore: PreviewStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        // Inject a tiny stylesheet that opts the default UA styling into both
        // light and dark color schemes, so pages that don't set their own
        // colors follow the system appearance instead of being forced white.
        let config = WKWebViewConfiguration()
        let source = """
        (function() {
            var s = document.createElement('style');
            s.textContent = ':root{color-scheme:light dark;}';
            document.documentElement.appendChild(s);
        })();
        """
        let script = WKUserScript(source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: config)
        // Follow the system appearance (do not force .aqua) so the preview is
        // dark-mode-aware.
        context.coordinator.webView = webView
        previewStore.webView = webView
        context.coordinator.load(html)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        previewStore.webView = webView
        context.coordinator.scheduleLoad(html)
    }

    // MARK: - Coordinator

    class Coordinator {
        weak var webView: WKWebView?
        private var debounceTimer: Timer?
        private var loadedHTML: String = ""

        func load(_ html: String) {
            loadedHTML = html
            webView?.loadHTMLString(html, baseURL: nil)
        }

        // Debounce so we don't reload on every keystroke while typing fast.
        func scheduleLoad(_ html: String) {
            guard html != loadedHTML else { return }
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.load(html)
            }
        }
    }
}
