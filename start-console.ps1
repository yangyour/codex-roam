$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$listener = Get-NetTCPConnection -LocalPort 4174 -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1
if ($listener) {
    exit 0
}

$nodeCandidates = @(
    'D:\nodejs\node.exe',
    (Get-Command node.exe -ErrorAction SilentlyContinue).Source
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

$node = $nodeCandidates | Select-Object -First 1
if (-not $node) {
    throw 'node.exe was not found'
}

Start-Process `
    -FilePath $node `
    -ArgumentList 'server.mjs' `
    -WorkingDirectory $projectRoot `
    -WindowStyle Hidden `
    -RedirectStandardOutput (Join-Path $projectRoot 'server.log') `
    -RedirectStandardError (Join-Path $projectRoot 'server-error.log')
