$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$easyTierRoot = Join-Path $projectRoot 'vendor/EasyTier'
$kcpRoot = Join-Path $projectRoot 'vendor/kcp-sys'
$kcpRevision = 'd7427c22d764deb1860a7d37acc446ed5033464c'

git -C $projectRoot submodule update --init --recursive vendor/EasyTier
if ($LASTEXITCODE -ne 0) { throw 'Unable to initialize the EasyTier submodule.' }

if (-not (Test-Path -LiteralPath (Join-Path $kcpRoot '.git'))) {
    git clone https://github.com/EasyTier/kcp-sys.git $kcpRoot
    if ($LASTEXITCODE -ne 0) { throw 'Unable to clone kcp-sys.' }
}
git -C $kcpRoot checkout --detach $kcpRevision
if ($LASTEXITCODE -ne 0) { throw 'Unable to checkout the pinned kcp-sys revision.' }

function Apply-ProjectPatch([string] $repository, [string] $patchPath) {
    git -C $repository apply --reverse --check $patchPath 2>$null
    if ($LASTEXITCODE -eq 0) { return }
    git -C $repository apply --check $patchPath
    if ($LASTEXITCODE -ne 0) { throw "Patch does not apply cleanly: $patchPath" }
    git -C $repository apply $patchPath
    if ($LASTEXITCODE -ne 0) { throw "Unable to apply patch: $patchPath" }
}

Apply-ProjectPatch $easyTierRoot (Join-Path $projectRoot 'patches/easytier-local-kcp.patch')
Apply-ProjectPatch $kcpRoot (Join-Path $projectRoot 'patches/kcp-sys-android-ndk.patch')

Write-Output 'EasyTier Android sources are ready.'
