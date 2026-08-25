import AppKit

/// The menu bar status item and its dropdown menu.
final class StatusBar: NSObject {
    private let item: NSStatusItem
    private let headerItem = NSMenuItem()
    private let statusItem = NSMenuItem()

    var onRefreshNow: (() -> Void)?
    var onLogin: (() -> Void)?
    var onOpenProfile: (() -> Void)?
    var onQuit: (() -> Void)?

    override init() {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        item.menu = buildMenu()
        setStatus(.loading)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        headerItem.isEnabled = false
        statusItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Refresh now", action: #selector(refreshNow)))
        menu.addItem(actionItem("Log in / Re-login…", action: #selector(logIn)))
        menu.addItem(actionItem("Open Lumen profile", action: #selector(openProfile)))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(actionItem("Quit LumenCoins", action: #selector(quit)))
        return menu
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let m = NSMenuItem(title: title, action: action, keyEquivalent: "")
        m.target = self
        return m
    }

    @objc private func refreshNow() { onRefreshNow?() }
    @objc private func logIn() { onLogin?() }
    @objc private func openProfile() { onOpenProfile?() }
    @objc private func quit() { onQuit?() }

    func setStatus(_ status: SessionStatus) {
        let barTitle: String
        switch status {
        case .loading:
            barTitle = "…"
            headerItem.title = "Coins Available"
            statusItem.title = "Loading…"

        case .ok(let value, let fetchedAt):
            barTitle = value.barText()
            headerItem.title = "Coins Available: \(value.detailText())"
            statusItem.title = "✓ Connected — updated \(Self.timeStr(fetchedAt))"

        case .stale(let last, _):
            barTitle = (last?.barText() ?? "—") + " ⚠"
            headerItem.title = "Coins Available: \(last?.detailText() ?? "—")"
            statusItem.title = "⚠ Offline — showing last value, retrying"

        case .sessionExpired:
            barTitle = "⚠"
            headerItem.title = "Coins Available"
            statusItem.title = "⚠ Session expired — choose Log in / Re-login"
        }

        if let button = item.button {
            if let img = NSImage(systemSymbolName: "bitcoinsign.circle.fill",
                                 accessibilityDescription: "Lumen coins") {
                img.isTemplate = true
                button.image = img
                button.title = " " + barTitle
            } else {
                button.image = nil
                button.title = "🪙 " + barTitle
            }
        }
    }

    private static func timeStr(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: d)
    }
}

private extension CoinValue {
    func barText() -> String {
        switch self {
        case .finite(let left, let cap):
            return cap.map { "\(fmt(left)) / \(fmtCap($0))" } ?? fmt(left)
        case .unlimited: return "∞"
        case .noPool: return "—"
        }
    }

    func detailText() -> String {
        switch self {
        case .finite(let left, let cap):
            return cap.map { "\(fmt(left)) / \(fmtCap($0))" } ?? fmt(left)
        case .unlimited: return "Unlimited"
        case .noPool: return "—"
        }
    }

    private func fmt(_ v: Double) -> String { String(format: "%.2f", v) }
    private func fmtCap(_ v: Double) -> String {
        v == v.rounded() ? String(format: "%.0f", v) : String(format: "%.2f", v)
    }
}
