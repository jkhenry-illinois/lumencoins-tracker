import Foundation

/// Parses the HTML returned by GET /profile into a CoinValue.
///
/// There is no JSON endpoint for the personal coin balance (see SPEC.md §2),
/// so we scrape the rendered profile card. The most stable anchor is the
/// progress bar's ARIA attributes, which Lumen emits whenever a finite cap is
/// set: `aria-label="Coin pool balance"`, `aria-valuenow="<coins_left>"`,
/// `aria-valuemax="<cap>"`. The "Unlimited" and "—" (no pool) states are
/// detected from the tile text.
enum CoinParse {
    static func parse(html: String) -> ParseResult {
        // The login page renders instead of the profile when the session is gone.
        if html.contains("<title>Lumen — Login</title>") || html.contains("Login with OAuth2") {
            return .loggedOut
        }

        guard let labelRange = html.range(of: "Coins Available") else {
            return .parseError
        }

        // The value markup follows the label within the same card.
        let start = labelRange.upperBound
        let end = html.index(start, offsetBy: 1000, limitedBy: html.endIndex) ?? html.endIndex
        let window = String(html[start..<end])

        // Primary: ARIA attributes on the progress bar (present when cap > 0).
        if let leftStr = capture(pattern: #"aria-valuenow="([0-9]*\.?[0-9]+)""#, in: window),
           let capStr = capture(pattern: #"aria-valuemax="([0-9]*\.?[0-9]+)""#, in: window),
           let left = Double(leftStr), let cap = Double(capStr) {
            return .value(.finite(coinsLeft: left, cap: cap))
        }

        if window.contains("Unlimited") {
            return .value(.unlimited)
        }

        // Em dash = no budget configured.
        if window.contains("—") {
            return .value(.noPool)
        }

        // Fallback: a bare "X.XX" (optionally " / Y.YY"). Covers the cap == 0
        // case where Lumen omits both the cap span and the progress bar.
        if let leftStr = capture(pattern: #">\s*([0-9]+(?:\.[0-9]+)?)"#, in: window),
           let left = Double(leftStr) {
            let capStr = capture(pattern: #"/\s*([0-9]+(?:\.[0-9]+)?)"#, in: window)
            return .value(.finite(coinsLeft: left, cap: capStr.flatMap(Double.init)))
        }

        return .parseError
    }

    private static func capture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges > 1 else {
            return nil
        }
        let r = match.range(at: 1)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
}
