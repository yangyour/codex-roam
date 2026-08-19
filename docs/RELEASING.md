# Release Guide

[简体中文](RELEASING.zh-CN.md)

## Release Boundaries

The repository can reproduce the Node bridge and Flutter client from source.
It does not commit private tokens, signing keys, generated APKs, or EasyTier
native build output. A maintainer must provide those release inputs privately.

## Preflight

1. Update `CHANGELOG.md` and both root README files.
2. Confirm `git status` contains no private files or unexpected submodule changes.
3. Run `npm ci`, `npm run check`, `flutter analyze`, and `flutter test`.
4. Build an ARM64 APK and inspect it with `tar -tf` for the expected EasyTier
   libraries and license notices.

## Android Signing

For local contributor builds, Flutter may use the debug signing key. Never ship
that APK as an official release. For a signed release, create the ignored file
`mobile/android/key.properties`:

```properties
storePassword=...
keyPassword=...
keyAlias=codexroam
storeFile=C:/secure/path/codexroam-upload.jks
```

The keystore and passwords must remain outside GitHub and outside build logs.
The Android Gradle configuration loads this file automatically when it exists;
without it, builds intentionally fall back to the debug key for contributors.

## Private Defaults

Do not use `.codex-roam.local.json` or `--dart-define` secrets for a public APK.
Those values are compiled into the binary. Public builds should require users
to enter connection settings in the app.

## EasyTier Native Libraries

Run `build-easytier-android.ps1` with the pinned submodule and required Rust,
Android NDK, Protobuf, and libclang versions. Keep the resulting `.so` files in
the private release workspace unless the distribution plan includes complete
corresponding-source and license obligations.

## GitHub Release

Push the version tag only after the checks pass:

```powershell
git tag vX.Y.Z
git push origin vX.Y.Z
```

Attach only the signed APK and public checksums. Do not attach private config,
tokens, debug-signed APKs, or unreviewed native binaries.
