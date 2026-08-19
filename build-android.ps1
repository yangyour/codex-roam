$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $projectRoot '.codex-roam.local.json'
$tokenPath = Join-Path $projectRoot '.codex-console-token'

if (-not (Test-Path -LiteralPath $configPath)) {
    throw 'Create .codex-roam.local.json from .codex-roam.example.json first.'
}
if (-not (Test-Path -LiteralPath $tokenPath)) {
    throw 'Start the bridge once so .codex-console-token is generated.'
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$token = (Get-Content -LiteralPath $tokenPath -Raw).Trim()
$flutter = (Get-Command flutter -ErrorAction Stop).Source
$defines = @(
    "--dart-define=CODEX_SERVER_URL=$($config.serverUrl)",
    "--dart-define=CODEX_FALLBACK_URL=$($config.fallbackUrl)",
    "--dart-define=CODEX_CONSOLE_TOKEN=$token",
    "--dart-define=EASYTIER_NETWORK_NAME=$($config.easyTierNetworkName)",
    "--dart-define=EASYTIER_NETWORK_SECRET=$($config.easyTierNetworkSecret)",
    "--dart-define=EASYTIER_PEER=$($config.easyTierPeer)",
    "--dart-define=EASYTIER_NETWORK_CIDR=$($config.easyTierNetworkCidr)"
)

Push-Location (Join-Path $projectRoot 'mobile')
try {
    & $flutter build apk --release --target-platform android-arm64 @defines
    if ($LASTEXITCODE -ne 0) { throw "Flutter build failed with exit code $LASTEXITCODE" }
} finally {
    Pop-Location
}
