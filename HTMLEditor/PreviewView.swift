import SwiftUI
import WebKit

struct PreviewView: NSViewRepresentable {
    var html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(true, forKey: "drawsTransparentBackground")
        context.coordinator.webView = webView
        context.coordinator.load(html)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
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
