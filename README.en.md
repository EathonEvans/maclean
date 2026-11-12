<p align="right"><a href="README.md">简体中文</a> · English</p>

<div align="center">

<img src="docs/assets/icon-256.png" width="112" alt="Maclean app icon"/>

# Maclean

**Turn off the display. Or enter cleaning mode.**

A macOS menu bar utility with two features: display sleep and cleaning mode.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-black?style=flat-square)
![Universal](https://img.shields.io/badge/arch-universal-555?style=flat-square)
[![License: MIT](https://img.shields.io/badge/license-MIT-2563EB?style=flat-square)](LICENSE)
[![Latest release](https://img.shields.io/github/v/release/EathonEvans/maclean?label=release&style=flat-square)](https://github.com/EathonEvans/maclean/releases)

[Download](https://github.com/EathonEvans/maclean/releases) · [Website](https://maclean.ethon-link.work) · [Issues](https://github.com/EathonEvans/maclean/issues)

</div>

> English translation of the [Chinese README](README.md). The app UI is currently Chinese-only.

## Features

**Display sleep**

Turns off all displays without locking the session or putting the Mac to sleep. Move the mouse or press a key to turn the displays back on.

**Cleaning mode**

All displays go black and keyboard input is blocked, so wiping the screen or keyboard triggers nothing.

To exit, rest the mouse on the card at the center of any screen for the configured duration (1.5 seconds by default, adjustable in Settings). The card shows the exit progress; moving the mouse away resets the timer.

Settings: launch at login, exit hover duration (0.5–5 seconds).

## Installation

Download the DMG or PKG from [Releases](https://github.com/EathonEvans/maclean/releases) and install to `/Applications`. Requires macOS 14 or later; Intel and Apple Silicon are both supported.

The app is not yet signed or notarized by Apple, so Gatekeeper may block the first launch:

- **macOS 15 and later**: open Maclean, then choose **Open Anyway** in System Settings → Privacy & Security.
- **macOS 14**: right-click Maclean, choose **Open**, and confirm.

Or run this in Terminal:

```bash
xattr -dr com.apple.quarantine /Applications/maclean.app
```

## Accessibility permission

Cleaning mode requires the Accessibility permission; display sleep does not.

The first time you start cleaning mode, follow the prompt to System Settings → Privacy & Security → Accessibility, enable Maclean, and try again. Without the permission, cleaning mode cannot start.

## Privacy

Maclean does not use the network, does not require login, and contains no analytics or ads.

During cleaning mode, keyboard input is discarded and its contents are never read. Mouse position is used only to detect the exit hotspot. Logging goes through the macOS unified logging system and contains no keystroke content.

## FAQ

<details>
<summary><strong>Does display sleep lock the screen or put the Mac to sleep?</strong></summary>

No. Display sleep only turns off the displays, without locking the session or sleeping the Mac. If you are leaving your computer, use the system screen lock (⌃⌘Q) instead.
</details>

<details>
<summary><strong>How do I exit cleaning mode?</strong></summary>

Rest the mouse on the card at the center of any screen for the configured duration (1.5 seconds by default). Moving the mouse away resets the timer. A cleaning session lasts at most 10 minutes, then exits automatically.
</details>

<details>
<summary><strong>Does cleaning mode read my keyboard input?</strong></summary>

No. Keystrokes are discarded during cleaning mode; their contents are never read.
</details>

<details>
<summary><strong>How do I uninstall?</strong></summary>

Quit Maclean and move `/Applications/maclean.app` to the Trash. If launch at login is enabled, remove it first in System Settings → General → Login Items.
</details>

<details>
<summary><strong>Why isn't it on the Mac App Store?</strong></summary>

The current implementation involves keyboard input interception and display control, so it is distributed separately as a DMG / PKG.
</details>

## Support the developer

Maclean is free and open source. If you find it helpful, you can buy the author a coffee or star the repo on GitHub.

<p align="center">
  <img src="docs/assets/donate-wechat.png" width="200" alt="WeChat QR code"/>
  &nbsp;&nbsp;&nbsp;&nbsp;
  <img src="docs/assets/donate-alipay.png" width="200" alt="Alipay QR code"/>
</p>
<p align="center"><sub>WeChat (left) · Alipay (right)</sub></p>

## License

[MIT](LICENSE) © 2026 EathonEvans
