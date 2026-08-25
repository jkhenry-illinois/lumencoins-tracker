# lumencoins-tracker

A macOS **menu bar app** that shows the **Coins Available** balance of your
personal [Lumen](https://lumen.ncsa.illinois.edu) account, refreshed about once
per minute. See `SPEC.md` for the full design.

It lives only in the menu bar (no Dock icon). On first launch it opens a window
for you to log in to Lumen via CILogon (your institution, including any MFA); the
app then reuses that session and re-prompts you to log in only when the session
expires. No password is ever stored — only the session cookie, kept in the
Keychain.

> **Note:** This is an unofficial, community-built tool. It is not affiliated with
> or endorsed by NCSA or the University of Illinois. "Lumen" is the name of the
> service at lumen.ncsa.illinois.edu; this app just reads the balance that service
> shows on your profile page.
>
> **Disclosure:** This tool was built using the GLM-5.2 model hosted on NCSA's Lumen

---

## Requirements (to run)

- An **Apple Silicon** Mac (M1 or later). The shipped binary is arm64-only.
- macOS 14 Sonoma or newer.
- A Lumen account (i.e. an institution that logs in through CILogon).

No Swift toolchain or Xcode is needed if you received the ready-made
`LumenCoins.app`. You only need the toolchain to **build from source** (below).

## Requirements (to build from source)

- The **Command Line Tools** Swift toolchain (`swift`). Full Xcode is **not**
  required.

Check yours:

```bash
swift --version          # needs Swift 5.9+
xcode-select -p          # /Library/Developer/CommandLineTools is fine
```

## Build & install

```bash
cd lumen-coins
swift build -c release                 # compile
bash packaging/make-app.sh             # builds LumenCoins.app, ad-hoc signed
```

Then launch:

```bash
open LumenCoins.app
```

To "install" it (optional), drag `LumenCoins.app` into `/Applications`. To make it
run at login, add it in **System Settings → General → Login Items**.

## First launch (Gatekeeper)

The app is **ad-hoc signed** (not notarized), so macOS Gatekeeper will block it on
first launch. This is expected. To open it:

1. In Finder, locate `LumenCoins.app`.
2. **Right-click** (or Control-click) the app and choose **Open**.
3. A dialog says the developer cannot be verified. Click **Open** anyway.
4. After that, it launches normally (double-click works from then on).

If you prefer the command line: `xattr -dr com.apple.quarantine /path/to/LumenCoins.app`
removes the quarantine flag entirely.

> This step is needed **once per Mac**. It does not grant the app any special
> privileges; it only tells Gatekeeper you trust this download.

## Using it

1. On first launch a **Log in to Lumen** window opens. Complete the CILogon login
   (institution + any MFA). The window closes automatically once you're logged in.
2. Your **Coins Available** balance appears in the menu bar, e.g. `🪙 42.18 / 100`.
   - `42.18 / 100` — coins left / cap.
   - `∞` — unlimited pool.
   - `—` — no pool configured for your account.
   - `⚠` — session expired (click → Log in / Re-login) or the value is stale and
     being retried.
3. Click the menu bar item for details and actions:
   - **Refresh now** — fetch immediately.
   - **Log in / Re-login…** — open the login window.
   - **Open Lumen profile** — open the profile page in your browser.
   - **Quit LumenCoins**.

The app refreshes every 60 seconds while your Mac is awake and a session is
present. After 3 consecutive failures it backs off to every 5 minutes until it
succeeds. It re-polls shortly after the Mac wakes from sleep.

## How it works

Lumen has **no JSON API for the personal coin balance** — that number only exists
in the HTML of `GET /profile`, which is session-authenticated (CILogon OAuth2).
Your personal API key can't reach it (it draws from a *project* coin pool). So the
app:

1. Logs you in through an embedded `WKWebView` (the normal Lumen web login).
2. Captures the resulting session cookie from the webview and stores it in the
   **Keychain**.
3. Every 60 s, fetches `/profile` with that cookie and parses the **Coins
   Available** tile — anchored on the progress bar's `aria-label="Coin pool
   balance"` / `aria-valuenow` / `aria-valuemax` attributes (with `Unlimited` and
   `—` text fallbacks).
4. If `/profile` redirects to `/login`, the session is treated as expired.

All network traffic goes only to `https://lumen.ncsa.illinois.edu`. Everything runs
locally; there is no telemetry.

## Verify the parser without launching the GUI

```bash
swift run LumenCoins --parse-self-test
```

## Project layout

```
lumen-coins/
├── SPEC.md                         design document
├── Package.swift                   SwiftPM manifest
├── .gitignore                      excludes .build/ and LumenCoins.app/
├── Sources/LumenCoins/
│   ├── main.swift                  entry point, AppDelegate, polling loop
│   ├── StatusBar.swift             menu bar item + dropdown menu
│   ├── LumenSession.swift          cookie store, /profile fetch, redirect handling
│   ├── LoginWindow.swift           WKWebView CILogon login + cookie capture
│   ├── KeychainStore.swift         session cookies persisted in Keychain
│   ├── ParseCoins.swift            HTML → CoinValue parser
│   ├── ParseSelfTest.swift         `--parse-self-test` checks
│   └── Models.swift                CoinValue / SessionStatus / ParseResult
├── packaging/
│   ├── Info.plist                  LSUIElement=true (menu-bar only)
│   └── make-app.sh                 builds + signs LumenCoins.app
└── README.md
```

## Sharing this app

You can hand someone either the pre-built app or the source — both work on their
own (no code changes needed).

- **Easiest: share the built app.** Send them `LumenCoins.app` (zipped is fine).
  They follow the [First launch (Gatekeeper)](#first-launch-gatekeeper) steps, then
  log in with their own Lumen account. Each user's session cookie is stored in
  *their own* Keychain, so sharing the app does **not** share any account data.
- **Share the source.** Zip or clone the directory. The `.gitignore` keeps
  machine-local build artifacts (`.build/`, `LumenCoins.app/`) out of a git
  checkout. Recipients run `swift build -c release && bash packaging/make-app.sh`.

There is no personal or machine-specific information baked into the app or the
source — only the Lumen service URL (`https://lumen.ncsa.illinois.edu`), which is
the same for everyone.

## Troubleshooting

- **First launch blocked by Gatekeeper** — right-click the app → Open.
- **A Keychain prompt appears on first run** — this is the app asking to store its
  session cookie. Click **Always Allow**. (The cookie is the only secret stored.)
- **Shows `⚠` / "Session expired"** — your Lumen session lapsed. Choose
  **Log in / Re-login…** and complete the CILogon login again.
- **Value looks wrong / stale** — choose **Refresh now**, or open the profile page
  to compare. If Lumen changes its profile-page markup, parsing may break; the app
  keeps the last known value with a `⚠` and logs the failure.
- **Want to reset** — quit the app, then clear the stored session:
  ```bash
  security delete-generic-password -s lumen.ncsa.illinois.edu -a LumenCoins.session-cookies
  ```
  (Relaunch and log in again.)

## Limitations

- **Apple Silicon only.** The binary is arm64; it will not launch on Intel Macs.
  (Rebuild with `--arch x86_64` if you need Intel support.)
- Parses the rendered profile HTML; a major Lumen UI change could break the
  parser (the ARIA anchor is the most stable part).
- Session lifetime is set by Lumen/CILogon; when it expires you must re-log in
  interactively (MFA can't be automated — by design).
- Not sandboxed / not notarized; intended for personal use on your own Mac.

