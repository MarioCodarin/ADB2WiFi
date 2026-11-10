# Roadmap & product notes

The goal is a five-second, no-terminal setup from USB to wireless ADB, with enough
visible state that a non-expert never has to guess what went wrong.

## Principles

1. **One primary action per card.** Connect, retry, or disconnect — never all three.
2. **Explain the fix, not the error code.** Every failure maps to an action.
3. **Show the endpoint.** Advanced users need the exact `adb` command; everyone else
   gets a copy button.
4. **Stay quiet.** No Dock icon, no notifications unless asked, no polling you can feel.
5. **Local-first.** No account, no cloud, no telemetry.

## Shipped in 0.2.0

- Setup screen with ADB picker, Homebrew command, and auto-detection.
- Redesigned popover: status-first cards, endpoint copying, `adb connect` copy button.
- Adaptive polling (1 s connecting / 3 s open / 60 s background), coalesced refreshes.
- Unified logging + redacted diagnostics report.
- Configurable ADB port and launch-at-login.
- Menu-bar icon shows when a phone is on Wi-Fi.
- Debug-only fixtures and a PNG snapshot renderer for visual QA.
- Native AppKit entry point (removes the phantom Settings window).

## Next opportunities

Scored by user value vs. effort. This is a brainstorm, not a commitment.

| Idea | Value | Effort | Notes |
|---|---|---|---|
| **Auto-reconnect last endpoint** | High | Medium | Remember the last `ip:port` per identity and try it on launch. Needs a "forget" control and a visible state. |
| **Android 11+ wireless debugging pairing** | High | High | `adb pair` flow with a pairing code / QR. Different UX from USB-initiated `tcpip`; should be a second card action. |
| **Open shell action** | High | Low | A "Shell" button that opens Terminal at `adb -s <endpoint> shell`. Needs careful quoting and a Terminal preference. |
| **Notifications on ready** | Medium | Low | One notification when a connection becomes verified, especially if the popover is closed. Must be opt-in. |
| **Last-connected device memory** | Medium | Low | Show a "Recently connected" card even when unplugged, with Reconnect. |
| **Multiple ports / profiles** | Medium | Medium | Useful for emulators and unusual devices. Keep the default 5555 and add a per-device override. |
| **Menu-bar right-click menu** | Medium | Low | Settings, Refresh, Launch at login, Quit without opening the popover. |
| **Localization** | Medium | Medium | The UI copy is short and centralized in `AppError` / `SetupView`; good candidate for `.strings`. |
| **Homebrew cask** | Medium | Low | Once notarized. A cask makes `brew install --cask adb2wifi` possible. |
| **Notarized release + Sparkle updates** | Medium | Medium | Requires a Developer ID. Removes the right-click-Open caveat. |
| **Session history** | Low | Medium | A small list of endpoints and durations. Privacy-sensitive; local only. |
| **scrcpy / logcat shortcuts** | Low | High | Out of scope: different product surface. |

## Explicitly out of scope

- Bundling or auto-installing Android Platform Tools.
- Rooting, unlocking, or modifying the phone.
- Screen mirroring, file transfer, logcat, or a full device manager.
- Cloud sync, accounts, analytics, or remote access.
- Managing or killing the ADB server.

## UX rules for future work

- The setup screen is the first-run product; keep it to one primary button.
- A failed connection always offers exactly one next step.
- Never hide a cached device row just because `adb` disappeared.
- Keep the popover under ~560 pt tall; scroll only when more than three phones are listed.
- Any new polling loop needs an idle story: what happens when the popover is closed
  and the Mac is asleep?
- Any new persisted data needs a redaction story for diagnostics.

## How to suggest an idea

Open a [GitHub Discussion or issue](https://github.com/MarioCodarin/ADB2WiFi/issues)
with the problem you hit first, not the implementation. Screenshots of the popover
are welcome; real serial numbers and IP addresses are not.
