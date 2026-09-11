# ADB2WiFi Design

Menu-bar-only native macOS utility that lists physical Android devices and establishes verified Wi-Fi ADB from an initial USB connection with one click.

## Summary

ADB2WiFi is a Swift 6 macOS 14+ menu-bar app. It never shows a Dock icon or a main window. The operator clicks the status item, sees attached physical phones in a 360-point popover, and taps **Connect via Wi-Fi**. The app follows Android’s USB-initiated workflow (`adb tcpip 5555` after USB authorization, then `adb connect <ipv4>:5555`) and only marks success after identity verification (`getprop ro.serialno`).

It uses an existing ADB executable on the Mac. It does not bundle, download, or auto-install ADB. It does not run `adb kill-server` / `adb start-server` as recovery. QR/code pairing, auto-reconnect, launch-at-login, mirroring, and file transfer are out of scope for v1.

## Design

The product is a status-item accessory:

- `NSStatusItem` (square length), template SF Symbol `iphone`, tooltip `ADB2WiFi`.
- Transient `NSPopover`, 360 points wide, hosting SwiftUI.
- Activation policy `.accessory` plus `LSUIElement=true` so nothing appears in the Dock.
- System light/dark. Popover chrome uses `.background(.regularMaterial)`. Accent is `Color(red: 0.22, green: 0.47, blue: 0.93)`.

Popover layout:

1. **Header** — title `ADB2WiFi`, device count, refresh (`arrow.clockwise`).
2. **Body** — scroll of device cards, or the empty state **Plug in an Android device**.
3. **Footer** — Settings and Quit. Settings swaps the popover body (no extra window).

Each card shows a phone icon, model, shortened serial (last eight characters), USB and Wi-Fi badges, and a primary **Connect via Wi-Fi** button. Connection progress stays inside the card as labeled steps: Finding address → Enabling Wi-Fi → Connecting → Verifying. Success is a green status plus **Ready—unplug USB.** Ambiguous addresses prompt with an inline IPv4 field and Continue. Failures show guidance and Retry.

Closing the popover must not cancel in-flight connection work. Quit leaves established ADB connections intact. Disconnect (later) removes only that computer’s Wi-Fi endpoint; it does not disable the phone’s TCP listener.

English UI only. App name `ADB2WiFi`. Bundle identifier `io.github.mariocodarin.ADB2WiFi`.

## Architecture

A Swift 6 package with two products:

| Target | Role |
|---|---|
| `ADB2WiFiCore` | UI-free library: ADB process client, parsers, device store, connection coordinator, settings. |
| `ADB2WiFi` | Executable: `NSStatusItem` + `NSPopover` + SwiftUI views. |

Core types: `DeviceIdentity`, `Device`, `Transport`, `TransportKind`, `Availability`, `OperationState`, `ConnectionStep`, `AppError`, `ADBTransport`, `AppSettings`.

Runtime objects (wired after the shell exists):

- **ADB client** — timed `Process` invocations, never `/bin/sh -c`. Device-targeted commands always pass `-s <serial>` first.
- **Device store** — polls `adb devices -l`, hides emulators, merges USB and network transports by verified `ro.serialno` (never by model name), caches models, preserves in-flight and ready-to-unplug cards when USB drops.
- **Connection coordinator** — exclusive per-device one-click connect, bounded retries, identity verification, disconnect of a single endpoint.
- **Views** — header, cards, empty state, settings pane, footer. Cards bind to `Device.operation`.

`AppSettings` stores `adbPathOverride` under UserDefaults key `adbPathOverride` and accepts a storage protocol so tests can inject memory-backed defaults.

Packaging: `Scripts/package-app.sh` builds a release arm64 binary and wraps it in `dist/ADB2WiFi.app` with `Resources/Info.plist`. No codesign or notarize in v1. Toolchain is Apple Swift + Command Line Tools (`swift build` / `swift test`), not Xcode.app.

## Discovery

ADB executable, first existing regular file that is executable:

1. `AppSettings.adbPathOverride`
2. `/opt/homebrew/bin/adb`
3. `/usr/local/bin/adb`
4. `~/Library/Android/sdk/platform-tools/adb`
5. `$ANDROID_HOME/platform-tools/adb` if set
6. `$ANDROID_SDK_ROOT/platform-tools/adb` if set
7. each directory in `PATH`

This Mac’s ADB is `/opt/homebrew/bin/adb` (v37.0.1); discovery still walks the full order.

Device list: `adb devices -l`. Ignore header and daemon-start noise. Hide `emulator-*`. Show unauthorized and offline physical devices. Poll every 2 seconds while the popover is open, every 10 seconds while closed, and on `NSWorkspace.didWakeNotification`.

Identity: for each non-emulator transport in state `device`, `adb shell getprop ro.serialno`. Unauthorized/offline transports cannot run shell; use the ADB serial as a provisional identity until they authorize. Merge USB (`usb:…`) and network (`host:port` or `._adb-tls-connect._tcp`) rows that share that serial. Two phones that share a model name stay two rows.

Wi-Fi IPv4: `adb -s <usbSerial> shell ip -o -4 addr show up`. Do not assume `wlan0`. Skip loopback, dummy, rmnet, ccmni, tun, ppp, sit, ip6tnl, and usb interfaces. Treat `wlan*`, `wifi*`, `wl*`, `swlan*`, `ap0` as Wi-Fi-like. If more than one Wi-Fi-like address remains, prompt before `tcpip`.

## One-click connection

Happy path, USB-initiated (Android’s “after an initial USB connection” path; QR/code pairing is deferred):

1. Snapshot the authorized USB transport. Missing → `usbRemoved`. Unauthorized → `authorizationPending`. Duplicate connect for the same identity is ignored; other devices stay clickable.
2. **Finding address** — shell `ip -o -4 addr show up` on the USB serial. If no unambiguous IPv4 and no manual address, set `awaitingAddress(suggested:)` and return **before** `tcpip`.
3. **Enabling Wi-Fi** — `adb -s <usbSerial> tcpip 5555`. Preserve the card if USB disappears (ADB restarts the daemon).
4. **Connecting** — retry `adb connect <ipv4>:5555` until success or a 20-second overall deadline from the start of this step. Parse stdout; `failed to connect` is not success even if the exit code is 0. `connected to` and `already connected to` are success.
5. **Verifying** — `adb -s <ipv4>:5555 shell getprop ro.serialno` must equal the captured `DeviceIdentity.serialNo` and be non-empty.
6. Mark `network.verified = true`, `operation = readyToUnplug`. Only then is the device Wi-Fi connected. Show **Ready—unplug USB.**

Manual address is validated as IPv4 (`#.#.#.#`); append `:5555` if no port.

Default ADB command timeout is 8 seconds, except `connect` uses the remaining deadline.

## Failures and lifecycle

| Condition | Result |
|---|---|
| ADB executable missing | `missingADB`; keep any already-listed devices |
| USB debugging not authorized | `authorizationPending`; do not call `tcpip` |
| Device offline | `deviceOffline` |
| No Wi-Fi-like IPv4 | `missingWiFiAddress` + Retry |
| `failed to connect` through the deadline | `unreachableEndpoint` |
| USB unplugged before `tcpip` | `usbRemoved` |
| USB unplugged after `tcpip` succeeded | continue connect/verify with the captured address |
| Command timeout | `timeout` |
| Verified serial does not match | `identityMismatch`; do not mark Wi-Fi connected |
| Duplicate click while connecting | ignored |
| Popover closed | in-flight work continues |
| Quit | stop polling; do **not** disconnect endpoints |
| Disconnect action | `adb disconnect <endpoint>` for that device only |

Unauthorized/offline cards show guidance instead of Connect. Retry reuses the last attempted address when one exists.

Never invoke `adb kill-server`. Never SIGKILL `adb` as the first timeout step; terminate (SIGTERM), then interrupt if it has not exited within 1 second.

## Implementation sequence

1. Package, models, menu-bar shell, fixture popover (this task).
2. Command runner and ADB executable discovery.
3. `adb devices -l` parsing and ADB client.
4. Identity merge, model cache, DeviceStore polling.
5. Wi-Fi IPv4 address discovery (no `wlan0` assumption).
6. Connection coordinator happy path, retries, verification.
7. Failures, disconnect, duplicate clicks, USB removal.
8. Live store in the popover, settings picker, final error copy.
9. Accessibility, reduced motion, packaging polish, README (hardware validation labeled pending until performed).

Core stays UI-free so Swift Testing can cover parsing, merging, targeting, timeouts, and connection state without AppKit. Fixture cards in the Task 1 shell are gated `#if DEBUG` or `ADB2WIFI_FIXTURES=1` so later release packaging can talk to live ADB.

## Defaults and Boundaries

**Defaults**

- macOS 14+, Swift language mode 6, Command Line Tools SDK.
- Bundle ID `io.github.mariocodarin.ADB2WiFi`, version `0.1.0`.
- ADB port 5555. Connect deadline 20 seconds. Command timeout 8 seconds.
- Poll 2 s open / 10 s closed.
- UserDefaults key `adbPathOverride`.
- Hardware validation on a real phone is pending and must be labeled as such; do not claim it passed.

**In scope**

- Menu-bar listing of physical USB/Wi-Fi ADB transports.
- One-click USB-initiated Wi-Fi ADB with identity verification.
- Settings override of the ADB path.
- Disconnect this Mac from one endpoint.

**Out of scope (v1)**

- Bundling, downloading, or installing ADB.
- QR pairing, pairing codes, wireless debugging pairing UI.
- Auto-reconnect, launch-at-login, mirroring, file transfer, scrcpy, logcat viewer.
- Managing or killing the ADB server.
- Non-English UI, Dock icon, main window, codesign/notarize.

## Key Decisions

- **Accessory, not a windowed app.** `LSUIElement` and `NSApp.setActivationPolicy(.accessory)` together hide the Dock. Status item + transient popover is the entire chrome.
- **Existing ADB only.** Discovery walks override → Homebrew → `/usr/local` → Android SDK → `PATH`. This machine’s Homebrew ADB is the expected hit, not a bundled binary.
- **USB-initiated `tcpip 5555` only.** Matches Android’s documented “after an initial USB connection” path. Pairing is deferred.
- **Merge by `ro.serialno`, never by model.** Two Pixels stay two cards. USB and `ip:5555` for the same phone become one card.
- **Hide emulators; keep unauthorized/offline physical devices.** Operators need the authorization/offline guidance, not an empty list.
- **Do not assume `wlan0`.** Prompt when multiple Wi-Fi-like IPv4s exist, and prompt before `tcpip` so we do not restart ADB on USB until an address is chosen.
- **Stdout, not exit code, decides `adb connect`.** `failed to connect` is failure even on exit 0.
- **Verified means shell identity matched.** A network transport is not “Wi-Fi connected” until `getprop ro.serialno` matches.
- **Preserve cards across USB drop after `tcpip`.** ADB restarts the USB transport; the in-flight operation and the ready-to-unplug state must survive.
- **Popover close is not cancel.** Coordinator and store live on `AppDelegate`, not the SwiftUI view lifetime.
- **Quit does not tear down Wi-Fi ADB.** The whole point is to unplug and keep working.
- **Never `adb kill-server`.** Recovery is Retry, replug, or choose another ADB path.
- **Testable core.** Fake command runner + Swift Testing cover parser/merge/coordinator cases. Hardware acceptance is a separate, explicit README line.
