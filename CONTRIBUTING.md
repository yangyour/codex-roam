# Contributing

[简体中文](CONTRIBUTING.zh-CN.md)

Thanks for helping improve CodexRoam. Keep contributions focused, reproducible,
and safe for a local coding-agent bridge.

## Before You Start

- Read the root README and the relevant configuration guide.
- Search existing Issues and pull requests before opening a new one.
- Never include bridge tokens, EasyTier secrets, private IP inventories,
  session files, screenshots containing prompts, or local logs with credentials.
- Do not add generated APKs, native `.so` files, build directories, or private
  config files to Git.

## Local Checks

```powershell
npm ci
npm run check

cd mobile
flutter pub get
flutter analyze
flutter test
```

Changes to embedded EasyTier or Android JNI should also include an ARM64 debug
or release build when the required native toolchain is available.

## Pull Requests

- Explain the user-visible behavior and the security impact.
- Keep one logical change per pull request.
- Add or update focused tests for changed behavior.
- Update both `README.md` and `README.zh-CN.md` when public workflow changes.
- Update the configuration or release guide when a setting or build prerequisite
  changes.
- Run golden tests locally on the target desktop renderer; CI excludes the
  `golden` tag because font rasterization differs between operating systems.
- Do not change the EasyTier submodule pointer unless the reason and upstream
  commit are documented.

Maintainers may ask for a smaller patch or additional verification before
merging.
