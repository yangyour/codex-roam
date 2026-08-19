# 配置说明

[English](CONFIGURATION.md)

## 桥接服务

桥接服务监听所有网卡，使局域网和 EasyTier 私有网络中的设备都能访问。支持以下
环境变量：

| 变量 | 默认值 | 用途 |
| --- | --- | --- |
| `PORT` | `4174` | HTTP 与 SSE 监听端口 |
| `CODEX_CONSOLE_TOKEN` | 自动生成本地文件 | 覆盖桥接服务访问令牌 |
| `CODEX_HOME` | Codex 默认值 | 指定 Codex 会话目录 |

未设置 `CODEX_CONSOLE_TOKEN` 时，首次启动会生成随机令牌并写入
`.codex-console-token`。请保护此文件。桥接服务通过 `x-codex-token` 请求头认证；
包含 `?token=` 的地址只用于本地首次配置，不应分享给他人。

## Android App

“连接设置”页面是主要配置入口。

| App 字段 | 示例 | 说明 |
| --- | --- | --- |
| 电脑地址 | `http://10.126.126.10:4174` | 优先填写电脑的 EasyTier 虚拟 IP |
| Wi-Fi 回退地址 | `http://192.168.1.10:4174` | 可选的局域网路径 |
| 访问令牌 | 隐藏 | 由桥接服务生成 |
| 启用内置 EasyTier | 开启 | 需要原生库和 Android VPN 权限 |
| 网络名称 | `my-private-network` | 必须与电脑一致 |
| 网络密钥 | 隐藏 | 使用独立随机密钥，必须与电脑一致 |
| 公共节点 | `tcp://peer.example.com:11010` | 手机和电脑都必须能访问 |
| 虚拟网段 | `10.126.126.0/24` | 必须包含电脑的虚拟 IP |

Android 13 及更高版本会在 App 首次启动时请求通知权限。如果拒绝权限，实时对话仍
然可用，但任务完成和阻塞提醒会被关闭，需到 Android 系统设置中重新开启。

配置通过 `SharedPreferences` 保存在手机本地。密码字段在界面中默认隐藏，但设备
备份或已被入侵的手机仍可能暴露应用数据，请勿复用其他服务的密码。

## EasyTier 参数对应关系

电脑端典型启动命令：

```text
easytier-core -d --ipv4 <电脑虚拟IP> --network-name <网络名称> --network-secret <网络密钥> -p <节点URI>
```

Android App 使用相同的网络名称、密钥和节点 URI，并把
`http://<电脑虚拟IP>:4174` 填入“电脑地址”。EasyTier 不同版本的命令行参数可能
变化，配置服务或自启动前请先查看已安装版本的 `--help`。

## 首次启动预填

如需构建包含个人预填值的私有 APK，将 `.codex-roam.example.json` 复制为
`.codex-roam.local.json`，仅在本地填写，先启动一次桥接服务，再运行：

```powershell
./build-android.ps1
```

脚本会把私有 JSON 和 `.codex-console-token` 映射为编译期 `--dart-define`。
这些值会被嵌入 APK，不适合公开发行。两个私有文件均不会被 Git 跟踪。

支持以下定义：

| 定义 | App 字段 |
| --- | --- |
| `CODEX_SERVER_URL` | 电脑地址 |
| `CODEX_FALLBACK_URL` | Wi-Fi 回退地址 |
| `CODEX_CONSOLE_TOKEN` | 访问令牌 |
| `EASYTIER_NETWORK_NAME` | 网络名称 |
| `EASYTIER_NETWORK_SECRET` | 网络密钥 |
| `EASYTIER_PEER` | 公共节点 |
| `EASYTIER_NETWORK_CIDR` | 虚拟网段 |

首次启动后，以 App 内保存的配置为准。

## 桌面 Skill

仓库包含 `codex-roam-setup` Skill，可在 Windows 上脱敏检查 EasyTier 进程和网卡、
桥接端口 `4174` 及桥接自启动任务。它在修改服务、计划任务或网络状态前会先征得
许可。安装方法见根目录 README。

## 常见问题

- **无法连接桥接服务：** 确认 `4174` 端口正在监听并使用私有地址，不要直接暴露
  到公网。
- **令牌无效：** 在本机获取桥接令牌，不要把它放进 Issue、截图或日志。
- **EasyTier 未连接：** 检查网络名、密钥、节点 URI、虚拟网段、Android VPN 权限
  以及原生 `.so` 文件是否存在。
- **Wi-Fi 可用但远程不可用：** 确认电脑 EasyTier 虚拟 IP 固定，且包含在 Android
  配置的虚拟网段内。
