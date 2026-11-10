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

## Shipped in 0.4.0

- Opt-in "ready" notification, posted only while the popover is closed.
- Recently connected list with model, endpoint, relative time, Reconnect, and Forget.
- Remembered metadata migration from the 0.3.x serial/endpoint shape.
- Notification permission guidance in Settings.

## Shipped in 0.3.0

- Opt-out auto-reconnect of the last verified endpoint on launch and wake.
- Remembered endpoints are local, capped, and clearable; explicit Disconnect forgets.
- Right-click status-item menu: Open, Settings, Refresh, Launch at Login, Quit.
- **Shell** action on connected cards, with a copy-command fallback if Terminal
  automation is denied.
- Launch-at-login approval guidance with a direct Login Items button.

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
| **Android 11+ wireless debugging pairing** | High | High | `adb pair` flow with a pairing code / QR. Different UX from USB-initiated `tcpip`; should be a second card action. |
| **Multiple ports / profiles** | Medium | Medium | Useful for emulators and unusual devices. Keep the default 5555 and add a per-device override. |
| **Notification actions** | Low | Low | Add a "Open ADB2WiFi" action to the ready notification. |
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
