import Foundation

/// Lightweight self-test for the HTML parser, runnable without Xcode/XCTest via
/// `swift run LumenCoins --parse-self-test`. Exercises the same code path the
/// live app uses against realistic rendered-HTML samples.
enum ParseSelfTest {
    static func run() -> Bool {
        var passed = 0
        var failed = 0

        func check(_ name: String, _ actual: ParseResult, _ expected: ParseResult) {
            if actual == expected {
                passed += 1
                print("  ✓ \(name)")
            } else {
                failed += 1
                print("  ✗ \(name): expected \(expected), got \(actual)")
            }
        }

        func checkValue(_ name: String, _ result: ParseResult, left: Double, cap: Double?) {
            guard case .value(.finite(let l, let c)) = result else {
                failed += 1
                print("  ✗ \(name): expected finite value, got \(result)")
                return
            }
            if abs(l - left) < 0.0001 && (cap == nil ? c == nil : (c != nil && abs(c! - cap!) < 0.0001)) {
                passed += 1
                print("  ✓ \(name)")
            } else {
                failed += 1
                print("  ✗ \(name): expected finite(\(left), \(String(describing: cap))), got \(result)")
            }
        }

        let finiteHTML = """
        <div class="profile-stat-card p-3 rounded border h-100">
          <div class="text-muted small mb-1">Coins Available</div>
          <div class="fw-bold fs-5 mb-2">42.18<span class="text-muted fw-normal fs-6"> / 100.00</span></div>
          <div class="progress" style="height:8px">
            <div class="progress-bar" role="progressbar"
                 aria-label="Coin pool balance"
                 style="width:42%"
                 aria-valuenow="42.18"
                 aria-valuemin="0" aria-valuemax="100.0"></div>
          </div>
        </div>
        <div class="col-4"><div>Refill Rate</div>+5.00/hr</div>
        """

        let unlimitedHTML = """
        <div class="profile-stat-card p-3 rounded border h-100">
          <div class="text-muted small mb-1">Coins Available</div>
          <div class="fw-bold fs-5 text-success">Unlimited</div>
        </div>
        """

        let noPoolHTML = """
        <div class="profile-stat-card p-3 rounded border h-100">
          <div class="text-muted small mb-1">Coins Available</div>
          <div class="fw-bold fs-5 text-muted">—</div>
        </div>
        """

        let bareNumberHTML = """
        <div class="profile-stat-card p-3 rounded border h-100">
          <div class="text-muted small mb-1">Coins Available</div>
          <div class="fw-bold fs-5 mb-2">0.00</div>
        </div>
        """

        let loginHTML = """
        <!doctype html><html><head><title>Lumen — Login</title></head>
        <body><a href="/login">Login with OAuth2</a></body></html>
        """

        print("Parse self-test:")
        checkValue("finite with cap", CoinParse.parse(html: finiteHTML), left: 42.18, cap: 100.0)
        check("unlimited", CoinParse.parse(html: unlimitedHTML), .value(.unlimited))
        check("no pool", CoinParse.parse(html: noPoolHTML), .value(.noPool))
        checkValue("bare number (cap==0)", CoinParse.parse(html: bareNumberHTML), left: 0.0, cap: nil)
        check("login detected", CoinParse.parse(html: loginHTML), .loggedOut)
        check("garbage -> parseError", CoinParse.parse(html: "<html>nothing</html>"), .parseError)

        print("\(passed) passed, \(failed) failed")
        return failed == 0
    }
}
