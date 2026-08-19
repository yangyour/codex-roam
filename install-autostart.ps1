$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$startScript = Join-Path $projectRoot 'start-console.ps1'
$powerShell = (Get-Command powershell.exe).Source
$taskName = 'CodexRoam Bridge'
$argument = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$startScript`""

$action = New-ScheduledTaskAction -Execute $powerShell -Argument $argument
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'Starts the CodexRoam bridge after user logon.' `
    -Force | Out-Null

Write-Output "Installed scheduled task: $taskName"
