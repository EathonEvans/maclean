<p align="right"><a href="README.md">简体中文</a> · English</p>

<div align="center">

<img src="docs/assets/icon-256.png" width="112" alt="Maclean app icon"/>

# Maclean

**Turn off the display. Or safely wipe it clean.**

A tiny macOS menu bar utility with exactly two jobs: sleep your displays, or enter a pure-black cleaning mode.
It does not lock your screen, does not sleep your Mac, does not use the network, and never reads your keystrokes.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Universal](https://img.shields.io/badge/arch-universal-555?style=flat-square)
[![License: MIT](https://img.shields.io/badge/license-MIT-2563EB?style=flat-square)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/EathonEvans/maclean?label=release&style=flat-square)](https://github.com/EathonEvans/maclean/releases)

[Download](https://github.com/EathonEvans/maclean/releases) · [Website](https://eathonevans.github.io/maclean/) · [Issues](https://github.com/EathonEvans/maclean/issues)

</div>

---

> This is a translation of the Chinese [README](README.md), which is the canonical version. The app UI is currently Chinese-only; English localization PRs are welcome.

Maclean sits in your menu bar and does two things: **sleep the displays** and **cleaning mode**.

It does not take over system settings, require an account, or run anything in the background beyond those two actions. Both features are small, but each has been built with the safety guards you want in a tool you leave installed.

## Why Maclean

- **Wipe your screen or keyboard without accidental input**: cleaning mode blocks ordinary keyboard input and turns every display pure black. No lock-then-unlock dance required.
- **A visible way out**: a persistent card sits in the center of each screen. Hover it for 1.5 seconds to exit. The card itself is the hotspot, so there is nothing to guess.
- **Guards against getting stuck**: the event tap exits safely if it keeps failing, a cleaning session is capped at 10 minutes, and a main-thread watchdog covers the worst case. If something goes wrong, these layers are there to get you back to the desktop.
- **Display sleep is not screen lock, and not system sleep**: it only turns the displays off. Running work is not interrupted, no re-authentication is required, and your sleep settings are untouched.
- **Fully offline**: no network, no account, no analytics. Key events are discarded inside the event callback and their contents are never read.

## Features

### Display sleep

Click **显示器休眠** (Display Sleep) in the menu bar and all displays turn off immediately.

- Only the displays sleep: no screen lock, no system sleep, no re-authentication, no changes to your sleep settings.
- No power assertions are held; the system command `pmset displaysleepnow` is used.
- Wake it the usual way: move the mouse, press a key, or press the power button (depending on your device and settings).
- Failures produce a clear error instead of failing silently.

> **Note**: display sleep is not the same as locking your screen. If you are leaving your Mac, lock it separately (default shortcut `⌃⌘Q`).

### Cleaning mode

Choose **清洁模式** (Cleaning Mode) from the menu bar. Every active display goes pure black and ordinary keyboard input is temporarily blocked.

- **Ordinary keyboard input is blocked**: `keyDown`, `keyUp`, and `flagsChanged` are filtered. Keystrokes are not read.
- **A visible exit**: each screen shows a persistent translucent card with a progress ring, “悬停 1.5 秒即可退出” (hover 1.5 seconds to exit), and “已禁用键盘” (keyboard disabled).
- **Hover to exit**: rest the mouse on the card for the configured duration. The default is 1.5 seconds; it can be set to 0.5–5 seconds in Settings.
- **Leaving resets the timer**: moving off the card resets progress immediately; moving from one screen to another starts a fresh timer.
- **Any screen can exit**: completing the hover on any display exits cleaning mode on all displays.
- **Safety guards**: a session ends automatically after 10 minutes; a persistently failing event tap triggers a safe exit; the keyboard is restored immediately on exit.
- **Multi-display**: each screen gets its own black window and hotspot. Hot-plugging and resolution changes are followed live, and mirrored displays are de-duplicated.

> **How do I exit?** Move the mouse to the central card and hover for 1.5 seconds (configurable). The card is the hotspot. Cleaning mode deliberately has no keyboard shortcut exit—the keyboard is being blocked; if the mouse is unavailable, the 10-minute cap will exit for you.

### Settings

- **Launch at login**: optional, via `SMAppService`; also manageable in System Settings → General → Login Items.
- **Hover duration**: 0.5–5 seconds, default 1.5 seconds.
- Everything else is intentionally left out.

## Installation

### Requirements

- macOS 14 Sonoma or later
- Intel or Apple Silicon (universal binary)
- Installer is roughly 2 MB

### Download

Get the latest build from [Releases](https://github.com/EathonEvans/maclean/releases):

- **DMG**: open it and drag Maclean into Applications.
- **PKG**: follow the installer; it installs to `/Applications`.

Installing into `/Applications` is recommended: launch-at-login (`SMAppService`) and permission memory are more reliable there.

### First launch

Maclean is not signed with an Apple Developer ID and is not notarized, so Gatekeeper will block the first launch. The steps depend on your macOS version:

**macOS 15 and later**

1. Double-click Maclean. macOS reports that it cannot verify the app.
2. Open **System Settings → Privacy & Security** and click **Open Anyway** in the Security section.
3. Enter your password and confirm; if the app does not launch automatically, double-click Maclean again.

**macOS 14**

1. In Finder, right-click (or Control-click) Maclean.
2. Choose **Open**, then click **Open** again in the dialog.

If you trust the download, you can also remove the quarantine attribute from Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/maclean.app
```

> Because the app is not notarized, a fresh download of a new version may ask for confirmation again. This is normal Gatekeeper behavior.

## Accessibility permission for cleaning mode

Display sleep needs no permissions. **Only keyboard blocking in cleaning mode requires Accessibility access**, and the app asks only when you first click Cleaning Mode.

1. Open Maclean and click **清洁模式**.
2. When prompted, click **Open System Settings**.
3. Enable Maclean under **Privacy & Security → Accessibility**.
4. Return to Maclean and click **清洁模式** again.

If Maclean is already enabled in the list but the app still reports a missing permission (common after a rebuild or signing change), select Maclean, click **−**, and grant access again.

**What happens if permission is denied?** Cleaning mode does not start: the app rolls back and shows an error. It will not leave you with a black screen and a false sense that the keyboard is blocked.

## Privacy

Maclean does not use the network, does not require an account, and contains no analytics, ads, or auto-updater.

- **Keyboard**: events are filtered only during cleaning mode. Their contents are never read, logged, or uploaded.
- **Mouse**: position is used only for hotspot detection during cleaning mode. No trajectory file is written, and nothing is uploaded.
- **Network**: the app makes no network requests.
- **Logs**: macOS unified logging (subsystem `com.ethon.maclean`) is used. It contains no keyboard content. During cleaning mode, a diagnostic entry with the mouse position and hotspot decision is written every 3 seconds to help debug hotspot and multi-display issues. There is no local log file.

You can inspect the logs yourself:

```bash
log show --predicate 'subsystem == "com.ethon.maclean"' --last 30m --style compact
```

## Known limitations

- Secure Input, system security UI, hardware function keys, and some reserved system shortcuts are not guaranteed to be intercepted. This is the boundary of a regular non-sandboxed app.
- Cleaning mode has no keyboard escape shortcut by design. If the mouse is unavailable, the 10-minute cap is the fallback.
- A cleaning session is capped at 10 minutes.
- If the system keeps disabling the event tap, cleaning mode exits safely, so a session may end early in extreme cases.
- Display sleep relies on `pmset`; if system policy blocks it, the app reports the failure instead of failing silently.
- macOS 14+ only. The app is not signed with an Apple Developer ID, not notarized, and not distributed through the Mac App Store.
- The app UI is currently Chinese-only.

## Build from source

### Requirements

- macOS 14+
- Xcode with command-line tools
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

### Build

```bash
git clone https://github.com/EathonEvans/maclean.git
cd maclean

./scripts/make-dev-cert.sh   # first build: create the local self-signed certificate maclean-dev
make assets                  # optional: regenerate icons from assets/logo.svg
make build                   # outputs build/maclean.app
make test                    # run the unit tests
make run                     # build and launch
make package                 # create DMG and PKG under dist/
```

The Xcode project is generated from `project.yml` by XcodeGen; `maclean.xcodeproj/` is not tracked. To work in Xcode:

```bash
make generate
open maclean.xcodeproj
```

### Why a self-signed certificate?

`project.yml` uses a local self-signed certificate named `maclean-dev` instead of ad-hoc signing. macOS ties the Accessibility permission to the code signature: an ad-hoc signature changes on every rebuild, so you would have to re-grant access each time. A stable certificate keeps the permission valid across builds.

`scripts/make-dev-cert.sh`:

1. generates a 10-year local code-signing certificate with `openssl`;
2. imports it into your login keychain;
3. marks it as a trusted local root.

The certificate is only used for local development signing. It is not uploaded anywhere and does not represent an Apple developer identity. Without running the script, `make build` fails because the `maclean-dev` certificate cannot be found.

> After a rebuild or signing change, the old Accessibility grant may become stale. Remove and re-add Maclean as described above.

### Build settings

| Item | Value |
| --- | --- |
| Deployment target | macOS 14.0 |
| Swift | 5.0 |
| Architecture | Universal (x86_64 + arm64) |
| Third-party runtime dependencies | None |

<details>
<summary><strong>Project layout</strong></summary>

```text
maclean/
├── maclean/
│   ├── App/                    # App lifecycle and dependency container
│   ├── Core/
│   │   ├── Display/            # Display identity and change monitoring
│   │   ├── Input/              # CGEventTap keyboard filtering
│   │   └── Utilities/          # Constants, logging, errors, alerts
│   ├── Features/
│   │   ├── Cleaning/           # Cleaning state machine, windows, HUD, hotspots
│   │   ├── DisplaySleep/       # Display sleep
│   │   ├── MenuBar/            # Menu bar panel
│   │   └── Settings/           # Settings
│   └── Resources/              # Icon assets
├── Tests/                      # 38 unit tests
├── scripts/                    # Asset generation, certificate, packaging
├── assets/                     # Brand SVG
├── docs/                       # GitHub Pages site and images
├── project.yml                 # XcodeGen project definition
└── Makefile
```

</details>

## Implementation notes

SwiftUI (menu bar panel, settings, HUD) + AppKit (full-screen windows, status item) + CoreGraphics (events, displays). No third-party runtime dependencies.

A few parts worth reading:

- **Dedicated EventTap thread**: the keyboard filter is created on its own thread, and the main thread waits at most 2 seconds. On timeout the app rolls back instead of blocking the UI. See [`KeyboardEventMonitor.swift`](maclean/Core/Input/KeyboardEventMonitor.swift).
- **Transactional enter/exit**: windows and listeners are prepared before anything is shown; any failure rolls back, and every exit path goes through one idempotent method. See [`CleaningManager.swift`](maclean/Features/Cleaning/CleaningManager.swift).
- **Hotspot = HUD**: the card and the hotspot share the same geometry, so what you see is exactly what you hover. See [`DisplayHotspot.swift`](maclean/Features/Cleaning/DisplayHotspot.swift).
- **Monotonic timing**: hover progress is based on elapsed real time, not timer ticks, with edge hysteresis to avoid jitter resets. See [`MousePositionMonitor.swift`](maclean/Features/Cleaning/MousePositionMonitor.swift).
- **Multi-display**: keyed by `CGDirectDisplayID`, with one window and hotspot per screen, rebuilt after hot-plug or wake. See [`CleaningWindowManager.swift`](maclean/Features/Cleaning/CleaningWindowManager.swift).
- **Generated icons**: one SVG produces the AppIcon, menu bar template, and menu item icons. See [`scripts/generate-assets.swift`](scripts/generate-assets.swift).

## FAQ

<details>
<summary><strong>Does it lock my screen or put my Mac to sleep?</strong></summary>

No. Display sleep only runs `pmset displaysleepnow` to turn off the displays. It does not lock the screen, sleep the Mac, or change system settings.
</details>

<details>
<summary><strong>Will the keyboard stay blocked forever?</strong></summary>

No. Exiting cleaning mode stops the event listener first, so the keyboard is restored immediately. The system reclaims the event tap if the app crashes, and the app stops the tap and exits safely if it fails. A session is additionally capped at 10 minutes.
</details>

<details>
<summary><strong>Why is there no keyboard shortcut to exit?</strong></summary>

Because cleaning mode exists to block the keyboard, any escape shortcut would have to be specially allowed, which increases the chance of accidental input. Exit by hovering the central card; if the mouse is unavailable, the 10-minute cap exits for you.
</details>

<details>
<summary><strong>Why does it need Accessibility permission? Does it read my keys?</strong></summary>

The permission is used only to filter key down/up events during cleaning mode. Events are discarded inside the callback; contents are not read, written to disk, or uploaded. Display sleep and the other features need no permissions.
</details>

<details>
<summary><strong>Does it support multiple displays and hot-plugging?</strong></summary>

Yes. Each display gets its own black window and hotspot. Plugging or unplugging a display, changing resolution, or rearranging screens is handled live. Mirrored displays are de-duplicated.
</details>

<details>
<summary><strong>How do I uninstall it?</strong></summary>

Quit Maclean and move `/Applications/maclean.app` to the Trash. If you enabled launch at login, disable it first in Settings → General (or System Settings → General → Login Items). You can remove the Accessibility entry in System Settings → Privacy & Security → Accessibility.
</details>

<details>
<summary><strong>Why is it not on the Mac App Store?</strong></summary>

Global keyboard filtering (CGEventTap) and display sleep (`pmset`) are not a good fit for the App Sandbox and App Store review model, so Maclean is distributed as a DMG/PKG.
</details>

<details>
<summary><strong>Does it support macOS 13?</strong></summary>

The minimum is macOS 14. Older versions are untested; compatibility PRs are welcome.
</details>

## Contributing

Issues and pull requests are welcome. For larger changes, please open an issue first to describe the use case and approach.

- Build and test commands are above; please run `make test` before submitting.
- The project deliberately has zero third-party runtime dependencies. Discuss any new dependency first.
- Cleaning-mode state must be owned by `CleaningManager`; other modules only report events.
- Do not log or upload keyboard content.

## Support

Maclean is free and open source under the MIT license, with no subscriptions or ads. If it saves you time, you can buy the author a coffee, or simply star the repo.

<p align="center">
  <img src="docs/assets/donate-wechat.png" width="180" alt="WeChat donation QR code"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/donate-alipay.png" width="180" alt="Alipay donation QR code"/>
</p>

## License

[MIT](LICENSE) © 2026 EathonEvans

Maclean is provided “as is”, without warranty of any kind. Display sleep does not lock your Mac; lock it yourself before leaving.
