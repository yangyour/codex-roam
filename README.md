# CodexRoam

[![CI](https://github.com/yangyour/codex-roam/actions/workflows/ci.yml/badge.svg)](https://github.com/yangyour/codex-roam/actions/workflows/ci.yml)
[![许可证：MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android：ARM64](https://img.shields.io/badge/Android-ARM64-3DDC84.svg)](mobile/README.md)

[English](README.en.md) | 简体中文

CodexRoam 是一个自托管的 Android 客户端，用来查看和控制你自己电脑上的
OpenAI Codex。它可以实时显示消息、推理摘要、命令输出和文件变更；内置的
EasyTier 客户端让手机离开家庭 Wi-Fi 后仍能通过私有网络连接电脑。

> CodexRoam 是独立开源项目，与 OpenAI 没有从属、认可或官方合作关系。

## 主要功能

- 类聊天应用的 Flutter Android 界面，支持实时增量输出
- 查看已有任务和完整历史，新建或继续 Codex 任务
- 发送指令、中断运行、处理命令执行审批
- Android 内置 EasyTier VPN，无需额外安装 VPN App
- 优先使用 EasyTier 地址，局域网 Wi-Fi 地址自动回退
- 在 App 内编辑并保存连接信息和 EasyTier 配置
- 任务完成或阻塞时发送 Android 本地通知
- 本地令牌认证，不依赖 CodexRoam 云账号，不收集遥测数据
- 附带桌面 Codex Skill，可安全检查桥接服务和 EasyTier 状态

## 架构

```text
Android / Flutter
  |  通过局域网或 EasyTier 使用 HTTP + SSE
  v
CodexRoam Node 桥接服务
  |  JSON-RPC
  v
codex app-server + 本地 Codex 会话文件
```

桥接服务直接消费 Codex 增量事件，同时监听本地 Codex 会话目录，因此桌面端
新建或更新的任务也会同步刷新到手机。

## 环境要求

- 安装了 Codex 的 Windows、macOS 或 Linux 电脑
- Node.js 22.12 或更高版本、npm 10 或更高版本
- Flutter 3.44 或更高版本及 Android SDK
- ARM64 Android 手机
- 需要离开同一 Wi-Fi 使用时，电脑端需安装 EasyTier

## 快速开始

克隆项目并拉取锁定版本的 EasyTier 源码：

```bash
git clone --recurse-submodules https://github.com/yangyour/codex-roam.git
cd codex-roam
npm ci
npm run build
npm start
```

桥接服务首次启动会创建 `.codex-console-token` 并打印连接地址。不要公开令牌或
包含令牌的完整地址。

Windows 可安装登录自启动任务：

```powershell
./install-autostart.ps1
```

构建仅支持局域网连接的 Android App：

```powershell
cd mobile
flutter pub get
flutter build apk --release --target-platform android-arm64
```

如需内置 EasyTier，必须先编译锁定版本的原生库。分发 APK 前请阅读
[配置说明](docs/CONFIGURATION.zh-CN.md)和[发布指南](docs/RELEASING.zh-CN.md)。

## App 配置

从任务抽屉或右上角菜单打开“连接设置”，可以编辑并持久化：

- 电脑地址和可选的 Wi-Fi 回退地址；
- 桥接服务访问令牌；
- 内置 EasyTier 开关、网络名称、网络密钥、公共节点和虚拟网段。

通过 `--dart-define` 传入的值只用于首次启动预填。App 保存过配置后，以本地
保存值为准。

Android 13 及更高版本请在首次提示时允许通知。提醒由 App 根据桥接服务的实时事件
在本机生成，不会发送到 CodexRoam 云服务。Android 可能回收后台 App；如果长时间
没有提醒，请确认桥接服务仍在运行并重新打开 App。

所有配置项、EasyTier 参数映射、私有预填构建和桌面端配置方法见：

- [配置说明（简体中文）](docs/CONFIGURATION.zh-CN.md)
- [Configuration (English)](docs/CONFIGURATION.md)

## 桌面配置 Skill

安装仓库内附带的 Codex 桌面 Skill：

```powershell
Copy-Item -Recurse -Force ./skills/codex-roam-setup `
  "$env:USERPROFILE/.codex/skills/codex-roam-setup"
```

然后对 Codex 说：`使用 $codex-roam-setup 配置这台电脑的远程连接`。该 Skill
只进行脱敏检查，不会输出网络密钥、访问令牌或进程命令行。

## 安全

CodexRoam 连接的是能够执行命令的编码代理。请把桥接令牌和 EasyTier 密钥视为
密码，谨慎处理手机上的审批请求，且不要从公网路由器直接转发 `4174` 端口。

支持版本和私下报告漏洞的方法见 [SECURITY.zh-CN.md](SECURITY.zh-CN.md)。

## 开发

```powershell
npm ci
npm run check

cd mobile
flutter pub get
flutter analyze
flutter test
```

生成的 EasyTier `.so` 文件不会提交到仓库，因此普通 CI 不编译原生 EasyTier。
所需 Rust、Android NDK、Protobuf 和 libclang 工具链见发布指南。

## 参与社区

- 提交 Pull Request 前阅读[贡献指南](CONTRIBUTING.zh-CN.md)。
- 参与项目时遵守[行为准则](CODE_OF_CONDUCT.md)。
- 重要变更记录见 [CHANGELOG.md](CHANGELOG.md)。
- 可复现的问题和范围明确的功能建议请使用 GitHub Issues。

## 相关项目

本项目参考了
[ccpocket](https://github.com/K9i-0/ccpocket)、
[codex-remote](https://github.com/yunyuchen/codex-remote) 和
[remodex](https://github.com/Emanuele-web04/remodex)。CodexRoam 使用独立实现的
Flutter 客户端和本地 Node 桥接服务。

## 许可证

CodexRoam 源码采用 [MIT License](LICENSE)。EasyTier 采用 LGPL-3.0，许可证与
声明位于 `mobile/assets/easytier/`，锁定版本的上游源码可通过 `vendor/EasyTier`
子模块获取。`kcp-sys` 采用 MIT 许可证。
