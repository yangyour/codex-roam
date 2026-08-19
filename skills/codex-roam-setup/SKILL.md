---
name: codex-roam-setup
description: Configure and troubleshoot the CodexRoam desktop bridge and EasyTier connection when setting up remote Android access to the user's own computer.
---

# CodexRoam Setup

Set up the desktop side of CodexRoam and translate its values to the Android
app without exposing credentials.

## Inspect First

On Windows, run `scripts/inspect-easytier.ps1` before proposing changes. It
reports EasyTier processes, adapters and virtual IPv4 addresses, bridge port
4174, and the CodexRoam autostart task. It intentionally omits command lines,
tokens, and network secrets.

Also inspect the repository's `README.md`, `.codex-roam.example.json`, and
startup scripts when they are available. Never read `.codex-console-token` or
`.codex-roam.local.json` into chat or logs. If a token is needed, tell the user
where to retrieve or enter it without displaying its value.

## Configure

Preserve the user's installed EasyTier variant. Prefer its GUI when it already
manages the network; otherwise use the installed `easytier-core`. Both desktop
and Android must use the same network name, non-empty network secret, and
public peer URI. The computer needs a stable virtual IPv4 address.

A typical CLI launch is:

```text
easytier-core -d --ipv4 <computer-virtual-ip> --network-name <network-name> --network-secret <network-secret> -p <peer-uri>
```

Do not substitute real secrets into terminal commands that will be quoted in a
response. Use interactive or local configuration where possible. Confirm the
installed version's `--help` before adding version-specific service flags.

Map desktop values to the Android app's **连接设置** page:

| Desktop value | App field |
| --- | --- |
| `http://<computer-virtual-ip>:4174` | 电脑地址 |
| `http://<computer-lan-ip>:4174` | Wi-Fi 回退地址 |
| EasyTier network name | 网络名称 |
| EasyTier network secret | 网络密钥 |
| `-p` peer URI | 公共节点 |
| Virtual network route, such as `10.126.126.0/24` | 虚拟网段 |

The access token comes from the CodexRoam bridge, not EasyTier. Enter it only
in the app's **访问令牌** field.

## Verify

Verify that EasyTier has a virtual IPv4 address, port 4174 is listening, and
the app can reach `http://<computer-virtual-ip>:4174`. For autostart, verify
both EasyTier and the `CodexRoam Bridge` scheduled task after a restart or
sign-in.

Before changing EasyTier configuration, installing or replacing services,
editing scheduled tasks, or starting/stopping network processes, explain the
exact change and obtain the user's permission. Do not commit, print, or log an
EasyTier secret, bridge token, or populated private config.
