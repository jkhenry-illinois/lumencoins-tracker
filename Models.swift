import Foundation

/// The parsed coin-balance value shown on the Lumen profile page.
enum CoinValue: Equatable {
    case finite(coinsLeft: Double, cap: Double?)  // cap is nil when no limit is displayed
    case unlimited
    case noPool
}

/// The full UI state of the menu bar item.
enum SessionStatus: Equatable {
    case loading
    case ok(value: CoinValue, fetchedAt: Date)
    case stale(lastValue: CoinValue?, fetchedAt: Date?)
    case sessionExpired
}

/// Outcome of a single /profile fetch + parse.
enum ParseResult: Equatable {
    case value(CoinValue)
    case loggedOut
    case networkError
    case parseError
}
