# 发布指南

[English](RELEASING.md)

## 发布边界

仓库可以从源码复现 Node 桥接服务和 Flutter 客户端，但不会提交个人令牌、签名密钥、
生成的 APK 或 EasyTier 原生构建产物。正式发布时，维护者必须在私有环境中提供这些
输入。

## 发布前检查

1. 更新 `CHANGELOG.md` 以及根目录中英文 README。
2. 确认 `git status` 没有个人配置、敏感文件或意外的子模块变化。
3. 运行 `npm ci`、`npm run check`、`flutter analyze` 和 `flutter test`。
4. 构建 ARM64 APK，并用 `tar -tf` 检查 EasyTier 原生库和许可证声明存在。

## Android 签名

贡献者本地构建可以使用 Flutter 的 debug 签名，但绝不能把它当作官方发行版。正式
签名时，在忽略文件 `mobile/android/key.properties` 中配置：

```properties
storePassword=...
keyPassword=...
keyAlias=codexroam
storeFile=C:/secure/path/codexroam-upload.jks
```

密钥库和密码必须保存在 GitHub 之外，也不能进入构建日志。Android Gradle 配置会在
文件存在时自动读取它；没有此文件时会有意回退到 debug 签名，方便贡献者构建，但不
能用于正式发行。

## 私有预填值

不要把 `.codex-roam.local.json` 或带 `--dart-define` 密钥的构建用于公开 APK。这些
值会被编译进二进制。公开构建应要求用户在 App 内填写连接设置。

## EasyTier 原生库

使用锁定的子模块以及指定版本的 Rust、Android NDK、Protobuf 和 libclang 运行
`build-easytier-android.ps1`。除非发行方案已包含完整的对应源码和许可证义务，否则
应把生成的 `.so` 保存在私有发布环境。

## GitHub Release

检查通过后再推送版本标签：

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

只附加正式签名 APK 和公开校验和。不要附加个人配置、令牌、debug 签名 APK 或未经
审查的原生二进制。
