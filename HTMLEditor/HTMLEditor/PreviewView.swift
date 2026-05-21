import SwiftUI
import WebKit
import Combine

/// Exposes the live preview `WKWebView` and the preview display options
/// (device width, live-reload, scroll-sync) so the toolbar and document actions
/// can drive it.
final class PreviewStore: ObservableObject {
    weak var webView: WKWebView?

    @Published var width: PreviewWidth = .responsive
    @Published var liveReload = true
    @Published var scrollSync = false

    /// Force a reload of the given HTML (used for manual reload when live-reload
    /// is off, and after toggling live-reload back on).
    func reload(_ html: String) {
        webView?.loadHTMLString(html, baseURL: nil)
    }

    /// Scroll the preview to the same vertical fraction as the editor.
    func syncScroll(fraction: Double) {
        guard scrollSync, let webView else { return }
        let clamped = min(max(fraction, 0), 1)
        let js = "window.scrollTo(0, (document.body.scrollHeight - window.innerHeight) * \(clamped));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}

struct PreviewView: NSViewRepresentable {
    var html: String
    @EnvironmentObject var previewStore: PreviewStore

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
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
        context.coordinator.webView = webView
        previewStore.webView = webView
        context.coordinator.load(html)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        previewStore.webView = webView
        if previewStore.liveReload {
            context.coordinator.scheduleLoad(html)
        }
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

        func scheduleLoad(_ html: String) {
            guard html != loadedHTML else { return }
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.load(html)
            }
        }
    }
}
