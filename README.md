# ADB2WiFi

Native macOS menu-bar utility that lists physical Android devices and establishes verified Wi-Fi ADB from an initial USB connection with one click.

It never shows a Dock icon or a main window. Click the status item, select a phone, and tap **Connect via Wi-Fi**. The app follows Android’s USB-initiated workflow (`adb tcpip 5555`, then `adb connect <ipv4>:5555`) and only marks success after identity verification (`getprop ro.serialno`).

## Requirements

- macOS 14 or later
- An existing ADB executable on the Mac. This project does not bundle, download, or install ADB.

Discovery order: Settings override → `/opt/homebrew/bin/adb` → `/usr/local/bin/adb` → `~/Library/Android/sdk/platform-tools/adb` → `$ANDROID_HOME` / `$ANDROID_SDK_ROOT` → `PATH`.

## Build, test, package

```
swift build
bash Scripts/test.sh
bash Scripts/package-app.sh
```

Use `bash Scripts/test.sh`, not bare `swift test`. Command Line Tools SwiftPM can exit 0 without running tests unless the Testing.framework toolset is applied.

The packaged app is `dist/ADB2WiFi.app` (`LSUIElement`, accessory activation policy, no Dock icon).

## First run

1. Enable USB debugging in Developer options on the phone.
2. Plug in USB and accept the authorization prompt on the phone.
3. Open the ADB2WiFi status item and tap **Connect via Wi-Fi**.

Wi-Fi ADB requires a reachable shared network. Use it only on a trusted network.

**Disconnect** removes only this Mac’s Wi-Fi ADB endpoint. It does not disable the phone’s TCP listener.

Quit leaves established ADB connections intact. Closing the popover does not cancel in-flight work.

## Hardware validation

- Discovery of an authorized USB phone: **observed 2026-09-11** (an authorized USB phone appeared in the popover within the first open; a pre-existing Wi-Fi a Wi-Fi phone was also listed).
- One-click verified Wi-Fi ADB + shell after unplug: **pending**.
- Two-phone hardware isolation: **pending** (unit tests cover targeting).

## Out of scope (v1)

- QR / pairing-code wireless debugging
- Auto-reconnect
- Launch at login
- Screen mirroring
- File transfer

See `docs/superpowers/specs/2026-09-11-adb2wifi-design.md`.
