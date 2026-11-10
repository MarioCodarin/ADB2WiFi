# Changelog

## 0.4.0 — 2026-11-10

### Added

- **Notify when ready** — opt-in local notification when a one-click connection is
  verified while the popover is closed. Requests notification permission when enabled.
- **Recently connected** — remembered phones appear under the active cards with
  **Reconnect** and **Forget**. Each entry keeps the model, endpoint, and last-connected
  time; entries that are currently listed are hidden.
- Remembered connections migrate from the 0.3.x `serial -> endpoint` format.

### Changed

- Remembered metadata now includes model and last-connected time, and drives both
  auto-reconnect and the recent list.
- Settings shows the remembered count and a Clear action, plus the notification toggle
  and permission guidance.

## 0.3.0 — 2026-11-10

### Added

- **Auto-reconnect** — remembers the last verified endpoint per phone and quietly tries it
  on launch or wake. Opt out, or clear the remembered list, in Settings. An explicit
  **Disconnect** forgets that endpoint.
- **Right-click status-item menu** — Open, Settings, Refresh Devices, Launch at Login,
  and Quit without opening the popover first.
- **Open Shell** — connected cards can open Terminal already attached to the phone. If
  macOS denies Terminal automation, the command is copied instead.
- Launch-at-login approval guidance: when macOS requires approval, Settings shows an
  **Open** button for the Login Items pane.

### Changed

- The connected-card action row now shows `Copy adb command`, `Shell`, and `Disconnect`.

## 0.2.1 — 2026-11-10

### Fixed

- Diagnostics now reports stable error case names instead of raw `adb` output, so a
  serial number or endpoint can never appear in a copied support report.
- Long `adb` errors are truncated before they reach the popover.
- In-flight polling is cancelled on sleep and quit; the process runner terminates its child.
- An address prompt is logged as `connect prompt`, not `connect ok`.

## 0.2.0 — 2026-11-10

### Added

- First-run setup screen with ADB auto-detection, a file picker, and a copy-ready
  Homebrew install command.
- Redesigned popover: status-first cards, endpoint copy, `adb connect` copy button,
  inline progress, and a connected menu-bar mark.
- Configurable ADB port (default 5555) and launch-at-login.
- `Copy diagnostics` report with home-directory redaction.
- Unified logging across `app`, `adb`, `devices`, `connection`, and `settings`.
- `ADB2WIFI_ADB_PATH` environment override.
- Adaptive polling and coalesced refreshes; polling pauses while the Mac sleeps.
- Debug-only fixture catalog and PNG snapshot renderer.
- Architecture, roadmap, security, and contributing docs; MIT license; CI.

### Changed

- Adaptive poll cadence: 1 s while connecting, 3 s with the popover open, 60 s in
  the background (previously 2 s / 10 s).
- `adb version` now reports the Platform Tools version (`37.0.1`) when available.
- AppKit entry point replaces the SwiftUI `App` scene; this removes a phantom
  Settings window on newer macOS SDKs.
- Bundle identifier changed to `io.github.mariocodarin.ADB2WiFi`.
- Packaging is ad-hoc signed and supports `--universal`; added install/release scripts.

### Removed

- Production fixture catalog and `Device.fixtureUSBAuthorized` (tests own their fixture).
- Unused `TransportKind`, `isADBMissing`, and old design/plan documents.
- Real hardware serials and local IPs from tests, fixtures, and history.

## 0.1.1 — 2026-09-30

- Debounced ADB version lookup and validated manual IPv4 endpoints.
- Deduplicated error mapping and tidied the device card.
- Built without the `@State` macro plugin on Command Line Tools.

## 0.1.0 — 2026-09-11

- Initial menu-bar app: device discovery, one-click USB-initiated Wi-Fi ADB,
  identity verification, retry, disconnect, and settings.
