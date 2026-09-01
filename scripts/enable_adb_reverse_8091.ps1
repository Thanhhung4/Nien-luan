[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$DeviceId,

    [Parameter(Mandatory = $false)]
    [int]$Port = 8091
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-AdbPath {
    $localProps = Join-Path $PSScriptRoot '..\android\local.properties'
    if (Test-Path $localProps) {
        $sdkLine = Get-Content $localProps | Where-Object { $_ -match '^sdk\.dir=' } | Select-Object -First 1
        if ($sdkLine) {
            $sdkRaw = ($sdkLine -split '=', 2)[1]
            $sdk = $sdkRaw.Replace('\\', '\')
            $adb = Join-Path $sdk 'platform-tools\adb.exe'
            if (Test-Path $adb) { return $adb }
        }
    }

    $adbCmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($adbCmd) { return $adbCmd.Source }

    throw "adb not found. Ensure Android SDK is installed and android/local.properties has sdk.dir."
}

function Resolve-DeviceId([string]$adbPath, [string]$explicitId) {
    if ($explicitId -and $explicitId.Trim() -ne '') {
        return $explicitId.Trim()
    }

    $lines = & $adbPath devices
    $deviceLines = $lines | Where-Object { $_ -match '^\S+\s+device$' }

    if (-not $deviceLines -or $deviceLines.Count -eq 0) {
        throw "No connected devices in 'device' state. Connect phone via USB and enable USB debugging."
    }

    $first = $deviceLines | Select-Object -First 1
    return ($first -split '\s+')[0]
}

$adbPath = Resolve-AdbPath
$resolvedDeviceId = Resolve-DeviceId -adbPath $adbPath -explicitId $DeviceId

Write-Host "Using adb: $adbPath"
Write-Host "Device: $resolvedDeviceId"
Write-Host "Enabling reverse tcp:$Port -> tcp:$Port"

& $adbPath start-server | Out-Null
& $adbPath -s $resolvedDeviceId reverse "tcp:$Port" "tcp:$Port"

Write-Host "Reverse rules:" 
& $adbPath -s $resolvedDeviceId reverse --list
