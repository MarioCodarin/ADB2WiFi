# Security policy

## Supported versions

The latest release (`0.3.x`) receives fixes. Older builds are not supported.

## Reporting a vulnerability

Please use GitHub's private
[Security Advisories](https://github.com/MarioCodarin/ADB2WiFi/security/advisories/new)
instead of opening a public issue. Include the app version, macOS version, and a
description of the impact. Do not include real serial numbers, IP addresses, or
personal data.

## What ADB2WiFi stores and sends

- **No accounts, API keys, analytics, or telemetry.**
- Settings are stored locally in `~/Library/Preferences/io.github.mariocodarin.ADB2WiFi.plist`:
  the optional `adb` path, the ADB port, and remembered serial/endpoint pairs used for
  opt-out auto-reconnect. The remembered list is capped at 20 and can be cleared in Settings.
- ADB commands run locally. The only network traffic is the ADB connection to the
  phone on your local network. Auto-reconnect only retries endpoints you previously
  verified; it does not scan the network.
- Logs use Apple's unified logging with serial numbers, endpoints, paths, and error
  payloads marked private. Public fields are limited to command verbs, counts,
  durations, and state names.
- **Copy diagnostics** is built by `Diagnostics.summary`; it redacts the home
  directory and contains no serial numbers or IP addresses.

## Repository hygiene

Fixture devices and tests use synthetic serials and documentation IP ranges.
`git history` was rewritten before the repository was made public to remove legacy
hardware identifiers. If you find a leaked identifier, report it privately.

## Terminal automation

The **Shell** action asks macOS for permission to control Terminal. If you decline,
ADB2WiFi copies the exact `adb` command to the clipboard instead. No data leaves the Mac.

## ADB over Wi-Fi

`adb tcpip` exposes an unencrypted ADB listener on the phone. Use it only on a
network you trust, and run **Disconnect** on shared networks. Disconnecting removes
this Mac's endpoint; it does not disable the phone's TCP listener. Rebooting the
phone or toggling wireless debugging turns the listener off.
