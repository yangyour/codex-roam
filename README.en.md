# CodexRoam

[![CI](https://github.com/yangyour/codex-roam/actions/workflows/ci.yml/badge.svg)](https://github.com/yangyour/codex-roam/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android: ARM64](https://img.shields.io/badge/Android-ARM64-3DDC84.svg)](mobile/README.md)

English | [简体中文](README.zh-CN.md)

CodexRoam is a self-hosted Android client for monitoring and controlling OpenAI
Codex on your own computer. It streams messages, reasoning summaries, command
output, and file changes in real time, while the embedded EasyTier client makes
the same private connection available away from your home Wi-Fi.

> CodexRoam is an independent open-source project. It is not affiliated with or
> endorsed by OpenAI.

## Highlights

- Chat-style Flutter Android client with live incremental output
- Browse existing tasks, inspect full history, and create or continue tasks
- Send prompts, interrupt active runs, and answer command approvals
- Embedded EasyTier VPN on Android; no separate VPN app is required
- EasyTier address first, with automatic local Wi-Fi fallback
- Editable connection and EasyTier settings inside the app
- Local Android notifications when a task completes or becomes blocked
- Local token authentication with no CodexRoam cloud account or telemetry
- Desktop Codex Skill for inspecting bridge and EasyTier setup safely

## Architecture

```text
Android / Flutter
  |  HTTP + SSE over LAN or EasyTier
  v
CodexRoam Node bridge
  |  JSON-RPC
  v
codex app-server + local Codex session files
```

The bridge consumes Codex delta events directly and watches the local Codex
session directory, so tasks started in Codex Desktop also refresh on the phone.

## Requirements

- Windows, macOS, or Linux computer with Codex installed
- Node.js 22.12 or newer and npm 10 or newer
- Flutter 3.44 or newer and an Android SDK for mobile development
- ARM64 Android phone
- EasyTier on the computer for access outside the local Wi-Fi

## Quick Start

Clone the repository, including the pinned EasyTier source:

```bash
git clone --recurse-submodules https://github.com/yangyour/codex-roam.git
cd codex-roam
npm ci
npm run build
npm start
```

The first bridge start creates `.codex-console-token` and prints a connection
URL. Never publish that token or the generated URL.

On Windows, install bridge autostart with:

```powershell
./install-autostart.ps1
```

Build a LAN-only Android app from source:

```powershell
cd mobile
flutter pub get
flutter build apk --release --target-platform android-arm64
```

To include embedded EasyTier, build the pinned native libraries first. See
[Configuration](docs/CONFIGURATION.md) and [Release Guide](docs/RELEASING.md)
before distributing an APK.

## App Configuration

Open **Connection settings** from the task drawer or overflow menu. The app can
edit and persist:

- computer URL and optional Wi-Fi fallback URL;
- bridge access token;
- embedded EasyTier enabled state, network name, secret, peer, and CIDR.

Values supplied through `--dart-define` are first-launch defaults only. Saved
in-app values take precedence after that.

On Android 13+, allow notifications when prompted. Alerts are generated locally
from the live bridge stream; no notification data is sent to a CodexRoam cloud
service. Android may stop background apps, so keep the bridge available and
reopen the app if the operating system has reclaimed it.

For every supported option, EasyTier value mapping, private prefilled builds,
and desktop setup, read:

- [Configuration (English)](docs/CONFIGURATION.md)
- [配置说明（简体中文）](docs/CONFIGURATION.zh-CN.md)

## Desktop Setup Skill

Install the included desktop Codex Skill:

```powershell
Copy-Item -Recurse -Force ./skills/codex-roam-setup `
  "$env:USERPROFILE/.codex/skills/codex-roam-setup"
```

Then ask Codex: `Use $codex-roam-setup to configure this computer for remote access.`
The Skill performs a redacted inspection and never prints network secrets,
tokens, or process command lines.

## Security

CodexRoam exposes a coding agent capable of running commands. Treat the bridge
token and EasyTier secret as passwords, review approval requests carefully,
and never forward port `4174` directly from a public router.

See [SECURITY.md](SECURITY.md) for supported versions and private reporting.

## Development

```powershell
npm ci
npm run check

cd mobile
flutter pub get
flutter analyze
flutter test
```

Native EasyTier compilation is intentionally separate from normal CI because
the generated `.so` files are not committed. See the release guide for the
required Rust, Android NDK, Protobuf, and libclang toolchain.

## Community

- Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.
- Follow the [Code of Conduct](CODE_OF_CONDUCT.md).
- Review notable changes in [CHANGELOG.md](CHANGELOG.md).
- Use GitHub Issues for reproducible bugs and scoped feature proposals.

## Related Projects

The implementation was informed by
[ccpocket](https://github.com/K9i-0/ccpocket),
[codex-remote](https://github.com/yunyuchen/codex-remote), and
[remodex](https://github.com/Emanuele-web04/remodex). CodexRoam uses its own
Flutter client and local Node bridge.

## License

CodexRoam source is licensed under the [MIT License](LICENSE). EasyTier is
LGPL-3.0 licensed; its license and notice are included in
`mobile/assets/easytier/`. The pinned upstream source remains available through
the `vendor/EasyTier` submodule. `kcp-sys` is MIT licensed.
