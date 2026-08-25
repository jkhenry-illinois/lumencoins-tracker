import AppKit
import WebKit

/// A window hosting a WKWebView that walks the user through Lumen's CILogon
/// OAuth2 login. On a successful landing on an authenticated Lumen page, the
/// session cookies are harvested from WKHTTPCookieStore and handed off. The app
/// never sees (nor stores) the user's password — only the resulting cookie.
final class LoginWindow: NSObject, NSWindowDelegate, WKNavigationDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?

    private let onLoginSuccess: ([HTTPCookie]) -> Void
    private let onClose: () -> Void

    init(onLoginSuccess: @escaping ([HTTPCookie]) -> Void, onClose: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
        self.onClose = onClose
    }

    func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let frame = NSRect(x: 0, y: 0, width: 960, height: 720)
        let w = NSWindow(contentRect: frame,
                         styleMask: [.titled, .closable, .miniaturizable, .resizable],
                         backing: .buffered, defer: false)
        w.title = "Log in to Lumen"
        w.delegate = self

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()  // persistent during the flow
        let wv = WKWebView(frame: frame, configuration: config)
        wv.navigationDelegate = self
        wv.autoresizingMask = [.width, .height]
        w.contentView = wv

        webView = wv
        window = w

        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        wv.load(URLRequest(url: URL(string: "https://lumen.ncsa.illinois.edu/login")!))
    }

    func close() {
        window?.close()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url, isAuthLumenURL(url) else { return }

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            let lumen = cookies.filter { $0.domain.contains("ncsa.illinois.edu") }
            guard !lumen.isEmpty else { return }
            DispatchQueue.main.async {
                self?.onLoginSuccess(lumen)
                self?.close()
            }
        }
    }

    /// True once we've landed back on a Lumen page that is not the login or the
    /// OAuth callback (i.e. authentication has completed).
    private func isAuthLumenURL(_ url: URL) -> Bool {
        guard url.host == "lumen.ncsa.illinois.edu" else { return false }
        let path = url.path
        return !path.contains("/login") && !path.contains("/callback")
    }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        webView?.navigationDelegate = nil
        webView = nil
        window = nil
        onClose()
    }
}
