# Architecture

ADB2WiFi is a menu-bar accessory with a UI-free core. The popover is the entire
product surface; there is no main window and no Dock icon.

## Targets

| Target | Role | Imports AppKit? |
|---|---|---|
| `ADB2WiFiCore` | ADB process client, parsers, device store, connection coordinator, settings, diagnostics, logging | No (Foundation/`os` only) |
| `ADB2WiFi` | `NSStatusItem`, `NSPopover`, SwiftUI views, launch-at-login | Yes |
| `ADB2WiFiCoreTests` | Swift Testing coverage for the core | No |

There are no third-party dependencies. Swift 6 language mode, macOS 14+.

## Runtime objects

`ADB2WiFiMain` is a tiny AppKit entry point that creates an `AppDelegate`. The
SwiftUI `App`/`Settings` scene was removed because newer SDKs create a hidden
Settings window for it; the whole UI is hosted in an `NSPopover` instead.

The delegate owns four long-lived objects:

- **`AppSettings`** — `adbPathOverride` and `port`, persisted in `UserDefaults`.
- **`DeviceStore`** — polling, identity/model caches, merged device list.
- **`ConnectionCoordinator`** — one-click connect, retry, verify, disconnect, cancel.
- **`StatusItemController`** — status item, popover lifecycle, file picker, icon state.

They live for the app's lifetime, so closing the popover never cancels work.

## Core types

| Type | Meaning |
|---|---|
| `DeviceIdentity` | Stable identity keyed by `ro.serialno`; `shortSerial` is the last 8 characters. |
| `Device` | One row: identity, model, optional USB and network `Transport`s, and an `OperationState`. |
| `Transport` | A concrete `adb` serial plus its `Availability` and whether its identity was verified. |
| `OperationState` | `idle`, `connecting(step)`, `awaitingAddress`, `readyToUnplug`, `failed(AppError)`. |
| `AppError` | User-facing title + guidance. `needsADBSetup` routes to the setup screen. |
| `ADBTransport` | Raw `adb devices -l` row before merging. |

`TransportMerger` is a pure function. It groups USB and network transports by
verified serial number, never by model name. It preserves in-flight and
ready-to-unplug rows across USB drop, because `adb tcpip` restarts the transport.

## Connection flow

```
USB authorized
  → detect Wi-Fi IPv4 over USB
  → adb tcpip <port>
  → adb connect <ipv4>:<port> (retry, 20 s budget)
  → adb -s <endpoint> shell getprop ro.serialno
  → compare with captured ro.serialno
  → readyToUnplug
```

Invariants:

- Commands are launched directly as `Process` argument arrays; never `/bin/sh -c`.
- Device-targeted commands always put `-s <serial>` first.
- `adb connect` success is parsed from stdout (`connected to` / `already connected to`),
  not from the exit code.
- A network transport is only `verified` after `ro.serialno` matches.
- `adb kill-server` is never invoked.
- A manual endpoint is strict IPv4, optional port, and validated before use.
- USB removal before `tcpip` fails; after `tcpip` the daemon restart is expected.
- On timeout: SIGTERM, then SIGINT, then SIGKILL as the last resort.
- Quit stops polling but leaves established ADB endpoints alive.

## Polling and resource use

`DeviceStore` uses one loop with an adaptive interval:

| State | Interval |
|---|---|
| A connection is in flight | 1 s |
| Popover is open | 3 s |
| Background | 60 s |

Opening the popover cancels the current sleep so the next refresh is immediate.
`NSWorkspace.willSleepNotification` stops the loop; `didWake` restarts it.

Refreshes are coalesced: while one `adb devices -l` is running, concurrent timer
or user refreshes await the same task. There is only one `adb` process per poll.

Identity and model values are cached per transport/serial, so a steady poll only
runs `adb devices -l`. `ProcessCommandRunner` caps each stream at 256 KB and
collects output with readability handlers, not a blocked thread per command.

## Logging

One subsystem, five categories:

```text
os.Logger(subsystem: "io.github.mariocodarin.ADB2WiFi", category: "app" | "adb" | "devices" | "connection" | "settings")
```

Logs are key-value shaped (`poll total=2 duration=38ms`). Serial numbers, endpoints,
paths, and error payloads are interpolated with `privacy: .private`; command verbs,
counts, durations, and state names are public. View them with:

```sh
log stream --predicate 'subsystem == "io.github.mariocodarin.ADB2WiFi"' --level debug
```

`Diagnostics.summary` produces a copyable support report with app/macOS version,
architecture, adb path (home redacted), adb version, device counts, and last error.
It never contains serial numbers or IP addresses.

## Settings

`AppSettings` uses a `DefaultsStorage` protocol so tests can inject memory-backed
defaults. `port` is clamped to `1...65535`; changing it affects the next connection.

`ADBExecutable.resolve` checks, in order: the Settings override, `$ADB2WIFI_ADB_PATH`,
Homebrew, `/usr/local`, MacPorts, the Android SDK in the home folder,
`$ANDROID_HOME` / `$ANDROID_SDK_ROOT`, then every `PATH` directory.

`LaunchAtLogin` wraps `SMAppService.mainApp`. The app must live in `/Applications`
for login-item registration to be meaningful.

## Testing and toolchain

`bash Scripts/test.sh` runs Swift Testing with the Command Line Tools toolset.
CLT ships `Testing.framework` but not its macro plugin, so the script loads
`libTestingMacros.dylib` when CLT is the active developer directory. With Xcode,
plain `swift test` also works.

The `@ViewState` typealias in `Theme.swift` is deliberate: newer SDKs declare
`@State` as a macro, and the macro plugin is absent from CLT-only toolchains.
The typealias resolves to the `State` property wrapper instead of the macro, so
`swift build` works without Xcode. Replace it with `@State` only when the
project requires Xcode.

## Where to extend

- **New ADB command** — add a method to `ADBClient`, keep arguments arrays, add a timeout test.
- **New parsed field** — update `ADBTransport`, `DeviceListParser`, and its tests.
- **New device state** — extend `OperationState`, `TransportMerger`, and the card's status/action switches.
- **New setting** — add it to `AppSettings` with a storage test, then surface it in `SettingsPaneView`.
- **New UI state** — keep `ConnectionCoordinator` as the only place that mutates connection state.
