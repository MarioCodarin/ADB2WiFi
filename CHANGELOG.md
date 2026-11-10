# Changelog

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
