import AppKit

// `swift run LumenCoins --parse-self-test` verifies the parser without launching
// the GUI (and without needing Xcode/XCTest).
if CommandLine.arguments.contains("--parse-self-test") {
    let ok = ParseSelfTest.run()
    exit(ok ? 0 : 1)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusBar = StatusBar()
    private let session = LumenSession()
    private var loginWindow: LoginWindow?

    private var timer: Timer?
    private var inFlight = false
    private var inBackoff = false
    private var consecutiveFailures = 0
    private var lastValue: CoinValue?
    private var lastFetchedAt: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)  // menu-bar only, no Dock icon

        statusBar.onRefreshNow = { [weak self] in self?.refresh() }
        statusBar.onLogin = { [weak self] in self?.promptLogin() }
        statusBar.onOpenProfile = {
            if let url = URL(string: "https://lumen.ncsa.illinois.edu/profile#models") {
                NSWorkspace.shared.open(url)
            }
        }
        statusBar.onQuit = { NSApp.terminate(nil) }

        if session.hasSession {
            statusBar.setStatus(.loading)
            refresh()
        } else {
            statusBar.setStatus(.sessionExpired)
            promptLogin()
        }
        startTimer(interval: 60)

        // Re-poll shortly after the Mac wakes from sleep.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            self?.refresh()
        }
    }

    private func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            if self.session.hasSession { self.refresh() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func refresh() {
        guard !inFlight, session.hasSession else { return }
        inFlight = true
        session.fetchProfile { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.inFlight = false
                self.handle(result)
            }
        }
    }

    private func handle(_ result: ParseResult) {
        switch result {
        case .value(let v):
            consecutiveFailures = 0
            lastValue = v
            lastFetchedAt = Date()
            if inBackoff { startTimer(interval: 60); inBackoff = false }
            statusBar.setStatus(.ok(value: v, fetchedAt: lastFetchedAt!))

        case .loggedOut:
            consecutiveFailures = 0
            session.clear()
            lastValue = nil
            lastFetchedAt = nil
            statusBar.setStatus(.sessionExpired)

        case .networkError, .parseError:
            consecutiveFailures += 1
            statusBar.setStatus(.stale(lastValue: lastValue, fetchedAt: lastFetchedAt))
            if consecutiveFailures == 3 && !inBackoff {
                inBackoff = true
                startTimer(interval: 300)  // back off to every 5 min until success
            }
        }
    }

    private func promptLogin() {
        if loginWindow == nil {
            loginWindow = LoginWindow(
                onLoginSuccess: { [weak self] cookies in
                    guard let self else { return }
                    self.session.replaceAll(cookies: cookies)
                    self.consecutiveFailures = 0
                    if self.inBackoff { self.startTimer(interval: 60); self.inBackoff = false }
                    self.refresh()
                },
                onClose: { [weak self] in self?.loginWindow = nil })
        }
        loginWindow?.show()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
