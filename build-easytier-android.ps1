$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
& (Join-Path $projectRoot 'prepare-easytier.ps1')
if ($LASTEXITCODE -ne 0) { throw 'EasyTier source preparation failed.' }

foreach ($command in @('cargo', 'cargo-ndk', 'protoc')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Missing build dependency: $command"
    }
}
if (-not $env:ANDROID_NDK_HOME -and -not $env:ANDROID_NDK_ROOT) {
    throw 'Set ANDROID_NDK_HOME or ANDROID_NDK_ROOT before building.'
}
if (-not $env:LIBCLANG_PATH) {
    throw 'Set LIBCLANG_PATH to the directory containing libclang.'
}

$easyTierRoot = Join-Path $projectRoot 'vendor/EasyTier'
Push-Location $easyTierRoot
try {
    cargo ndk -t arm64-v8a build --release -p easytier-android-jni -p easytier-ffi
    if ($LASTEXITCODE -ne 0) { throw "EasyTier build failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}

$jniRoot = Join-Path $projectRoot 'mobile/android/app/src/main/jniLibs/arm64-v8a'
New-Item -ItemType Directory -Force $jniRoot | Out-Null
Copy-Item (Join-Path $easyTierRoot 'target/aarch64-linux-android/release/libeasytier_android_jni.so') $jniRoot -Force
Copy-Item (Join-Path $easyTierRoot 'target/aarch64-linux-android/release/libeasytier_ffi.so') $jniRoot -Force
Write-Output "EasyTier JNI libraries copied to $jniRoot"
