# CodexRoam Android Client

Flutter client for the CodexRoam self-hosted bridge. Build configuration and
embedded EasyTier instructions are documented in the repository root
[README](../README.md) and [configuration guide](../docs/CONFIGURATION.md).

The app targets `arm64-v8a`. A normal contributor build uses the Android debug
signing key and is not suitable for distribution. Maintainers can configure a
private `android/key.properties` file for release signing; see the
[release guide](../docs/RELEASING.md).

```powershell
flutter pub get
flutter analyze
flutter test
```
