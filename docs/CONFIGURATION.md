# Configuration

[简体中文](CONFIGURATION.zh-CN.md)

## Bridge

The bridge listens on all interfaces so private LAN and EasyTier peers can
reach it. Its supported environment variables are:

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `4174` | HTTP and SSE listening port |
| `CODEX_CONSOLE_TOKEN` | generated local file | Overrides the bridge access token |
| `CODEX_HOME` | Codex default | Selects the Codex session directory |

When `CODEX_CONSOLE_TOKEN` is absent, the first start creates a random token in
`.codex-console-token`. Keep this file private. The bridge accepts the token in
the `x-codex-token` header; URLs containing `?token=` are intended only for
local onboarding and should not be shared.

## Android App

The **Connection settings** page is the primary configuration surface.

| App field | Example | Notes |
| --- | --- | --- |
| EasyTier computer URL | `http://10.126.126.10:4174` | The computer's EasyTier virtual IP |
| Wi-Fi fallback URL | `http://192.168.1.10:4174` | Optional LAN route |
| Access token | hidden | Value created by the bridge |
| Enable embedded EasyTier | on | Requires native libraries and Android VPN permission |
| Network name | `my-private-network` | Must match the computer |
| Network secret | hidden | Use a unique random secret; must match the computer |
| Public peer | `tcp://peer.example.com:11010` | Must be reachable by both devices |
| Virtual CIDR | `10.126.126.0/24` | Must contain the computer's virtual IP |

Android 13 and newer asks for notification permission the first time the app
starts. If permission is denied, the live conversation still works but task
completion and blocked-task alerts remain disabled until enabled in Android
system settings.

All fields are persisted locally with `SharedPreferences`. Password fields are
obscured in the UI, but device backups or a compromised device may still expose
application data. Do not reuse credentials from other services.

## EasyTier Mapping

A typical desktop command is:

```text
easytier-core -d --ipv4 <computer-virtual-ip> --network-name <network-name> --network-secret <network-secret> -p <peer-uri>
```

Use the same network name, secret, and peer URI in the Android app. Enter
`http://<computer-virtual-ip>:4174` as the computer URL. EasyTier CLI flags can
change between versions, so check the installed version's `--help` before
configuring a service or autostart entry.

## First-Launch Defaults

For a private APK with prefilled values, copy `.codex-roam.example.json` to
`.codex-roam.local.json`, fill it locally, start the bridge once, then run:

```powershell
./build-android.ps1
```

The script maps the private JSON and `.codex-console-token` to compile-time
`--dart-define` values. These values are embedded in the APK and are not
appropriate for a public release. Neither private file is tracked by Git.

Supported defines are:

| Define | App field |
| --- | --- |
| `CODEX_SERVER_URL` | Computer URL |
| `EASYTIER_ADDRESS` | EasyTier computer URL (takes precedence during first-launch prefill) |
| `CODEX_FALLBACK_URL` | Wi-Fi fallback URL |
| `CODEX_CONSOLE_TOKEN` | Access token |
| `EASYTIER_NETWORK_NAME` | Network name |
| `EASYTIER_NETWORK_SECRET` | Network secret |
| `EASYTIER_PEER` | Public peer |
| `EASYTIER_NETWORK_CIDR` | Virtual CIDR |

Saved in-app settings override these defaults after first launch.

## Desktop Skill

The included `codex-roam-setup` Skill performs a read-only, redacted Windows
inspection of EasyTier processes, adapters, bridge port `4174`, and the bridge
autostart task. It asks before changing services, scheduled tasks, or network
state. Installation is documented in the root README.

## Troubleshooting

- **Bridge unreachable:** confirm port `4174` is listening and use a private
  address; do not expose it directly to the internet.
- **Invalid token:** retrieve the local bridge token without posting it in an
  issue, screenshot, or log.
- **EasyTier not connected:** verify the name, secret, peer URI, virtual CIDR,
  Android VPN permission, and presence of native `.so` files.
- **Wi-Fi works but remote access fails:** confirm the desktop EasyTier virtual
  IP is stable and belongs to the Android virtual CIDR.
