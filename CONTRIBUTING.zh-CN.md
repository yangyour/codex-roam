# 贡献指南

[English](CONTRIBUTING.md)

感谢你改进 CodexRoam。请让贡献保持聚焦、可复现，并适合本地编码代理桥接场景。

## 开始前

- 阅读根目录 README 和相关配置说明。
- 提交新 Issue 前先搜索已有 Issue 和 Pull Request。
- 不要上传桥接令牌、EasyTier 密钥、私有 IP 清单、会话文件、包含提示词的截图，
  或含凭据的本地日志。
- 不要把 APK、原生 `.so`、构建目录或个人配置文件加入 Git。

## 本地检查

```powershell
npm ci
npm run check

cd mobile
flutter pub get
flutter analyze
flutter test
```

如果修改了 EasyTier 或 Android JNI，在工具链可用时还应完成 ARM64 debug 或
release 构建。

## Pull Request

- 说明用户可见行为和安全影响。
- 一个 Pull Request 只处理一个逻辑变更。
- 为改动行为补充或更新针对性测试。
- 公开工作流变化时，同时更新 `README.md` 和 `README.zh-CN.md`。
- 配置项或构建前置条件变化时，更新配置或发布指南。
- 在目标桌面渲染环境本地运行 golden 测试；CI 会排除 `golden` 标签，因为不同
  操作系统的字体栅格化结果不同。
- 除非有明确原因并记录上游提交，否则不要修改 EasyTier 子模块指针。

维护者可能要求缩小补丁范围或增加验证后再合并。
