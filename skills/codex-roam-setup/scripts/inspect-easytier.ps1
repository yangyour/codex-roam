$ErrorActionPreference = 'Stop'

function Invoke-SafeCheck {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Script,
        [Parameter(Mandatory)]
        $Fallback
    )

    try {
        & $Script
    } catch {
        $Fallback
    }
}

$easyTierProcesses = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like 'easytier*' } |
        Sort-Object ProcessName, Id |
        ForEach-Object {
            [ordered]@{
                name = $_.ProcessName
                id = $_.Id
            }
        }
)

$adapters = @(Invoke-SafeCheck -Fallback @() -Script {
    Get-NetAdapter -IncludeHidden -ErrorAction Stop |
        Where-Object {
            $_.Name -like '*EasyTier*' -or
            $_.InterfaceDescription -like '*EasyTier*'
        } |
        Sort-Object ifIndex |
        ForEach-Object {
            $adapter = $_
            $addresses = @(
                Get-NetIPAddress -InterfaceIndex $adapter.ifIndex `
                    -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Where-Object { $_.IPAddress -notlike '169.254.*' } |
                    Select-Object -ExpandProperty IPAddress
            )
            [ordered]@{
                name = $adapter.Name
                status = $adapter.Status.ToString()
                ipv4 = $addresses
            }
        }
})

$bridgeListeners = @(Invoke-SafeCheck -Fallback @() -Script {
    Get-NetTCPConnection -LocalPort 4174 -State Listen -ErrorAction Stop |
        Sort-Object LocalAddress, OwningProcess |
        ForEach-Object {
            $processName = (Get-Process -Id $_.OwningProcess `
                -ErrorAction SilentlyContinue).ProcessName
            [ordered]@{
                address = $_.LocalAddress
                port = $_.LocalPort
                process = $processName
            }
        }
})

$autostart = Invoke-SafeCheck -Fallback ([ordered]@{ installed = $false }) -Script {
    $task = Get-ScheduledTask -TaskName 'CodexRoam Bridge' -ErrorAction Stop
    $info = Get-ScheduledTaskInfo -TaskName 'CodexRoam Bridge' -ErrorAction Stop
    [ordered]@{
        installed = $true
        state = $task.State.ToString()
        lastResult = $info.LastTaskResult
        lastRun = $info.LastRunTime
        nextRun = $info.NextRunTime
    }
}

[ordered]@{
    easyTierProcesses = $easyTierProcesses
    easyTierAdapters = $adapters
    bridgePort4174 = $bridgeListeners
    codexRoamAutostart = $autostart
} | ConvertTo-Json -Depth 6
