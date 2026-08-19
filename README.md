# CodexRoam

Self-hosted Android remote control for OpenAI Codex. Monitor live Codex tasks,
stream responses and command output, send prompts, handle approvals, and connect
back to your own computer through the embedded EasyTier VPN.

CodexRoam 是一个自托管的 Codex 安卓远程客户端。电脑运行轻量 Node.js
桥接服务，手机通过局域网或内置 EasyTier 私有网络连接，不需要公网服务器。

> CodexRoam is an independent open-source project. It is not affiliated with or
> endorsed by OpenAI.

## Features

- Flutter Android client with a ChatGPT-style conversation interface
- Live Codex message, reasoning summary, command, and file-change streaming
- Existing conversation list and full conversation history
- Start new tasks, continue tasks, interrupt runs, and answer approvals
- Embedded EasyTier VPN; no separate VPN app is required on the phone
- EasyTier route first with optional local Wi-Fi fallback
- Local token authentication with no cloud account or telemetry

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

The bridge consumes Codex `item/agentMessage/delta`,
`item/reasoning/summaryTextDelta`, and `item/commandExecution/outputDelta`
events directly. It also watches the local Codex session directory so tasks
started in Codex Desktop refresh on the phone.

## Requirements

- Windows, macOS, or Linux computer with Node.js 20+ and Codex installed
- Flutter 3.35+ and Android SDK for building the app
- ARM64 Android phone
- EasyTier on the computer when remote access outside the local Wi-Fi is needed

## Start The Bridge

```powershell
npm install
npm run build
npm start
```

The first start creates a random token in `.codex-console-token` and prints a
URL similar to:

```text
CODEX_CONSOLE_URL=http://192.168.1.10:4174/?token=...
```

On Windows, `install-autostart.ps1` installs a login task that starts the bridge
automatically.

## Configure The Android App

Copy `.codex-roam.example.json` to `.codex-roam.local.json` and configure:

- `serverUrl`: the computer's EasyTier URL
- `fallbackUrl`: optional local Wi-Fi URL
- `easyTierNetworkName` and `easyTierNetworkSecret`: your private network
- `easyTierPeer`: a reachable EasyTier public peer
- `easyTierNetworkCidr`: the private route installed by Android VPN

Use a unique, non-empty EasyTier network secret. The local config and bridge
token are ignored by Git and must never be committed.

Build a personalized APK with prefilled connection details:

```powershell
./build-android.ps1
```

The APK is written to `mobile/build/app/outputs/flutter-apk/app-release.apk`.
At first launch Android asks for VPN permission once.

To build without private defaults, run:

```powershell
cd mobile
flutter pub get
flutter build apk --release --target-platform android-arm64
```

You can then enter the bridge URL and token on the connection screen. Embedded
EasyTier starts only when its compile-time settings are present.

## Build Embedded EasyTier

Prebuilt ARM64 `.so` files are distributed separately from source control. To
rebuild them, install Rust 1.95, `cargo-ndk`, Android NDK, Protobuf, and
libclang, then set `ANDROID_NDK_HOME` and `LIBCLANG_PATH`:

```powershell
./build-easytier-android.ps1
```

EasyTier is pinned as a Git submodule at commit
`57eb6908f4fc160f26946a14c672393a52df1101`. The preparation script clones the
pinned `kcp-sys` revision and applies the Windows/Android NDK patches stored in
`patches/` before compiling.

## Security

- API and event endpoints require the random bridge token.
- The bridge rejects requests outside loopback, private IPv4 ranges, and local
  IPv6 ranges.
- New Codex tasks use `workspace-write` and `on-request` approval by default.
- Do not forward port `4174` from a public router.
- Do not publish `.codex-console-token` or `.codex-roam.local.json`.

See [SECURITY.md](SECURITY.md) for reporting guidance.

## Development

```powershell
npm run build
cd mobile
flutter analyze
flutter test
```

## Related Projects

The implementation was informed by the open-source Codex remote-control
ecosystem, including
[ccpocket](https://github.com/K9i-0/ccpocket),
[codex-remote](https://github.com/yunyuchen/codex-remote), and
[remodex](https://github.com/Emanuele-web04/remodex). CodexRoam uses its own
Flutter client and local Node bridge.

## License

CodexRoam source is licensed under the [MIT License](LICENSE). EasyTier is
licensed under LGPL-3.0; its license and notice are included under
`mobile/assets/easytier/`. `kcp-sys` is MIT licensed. See the pinned upstream
sources and `patches/` for the complete corresponding native source.
