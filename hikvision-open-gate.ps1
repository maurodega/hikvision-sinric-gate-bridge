<#
  Opens the Hikvision gate through the indoor monitor.

  Password is read from HIKVISION_GATE_PASSWORD and is never stored here.
  Optional environment overrides:
    HIKVISION_MONITOR_IP
    HIKVISION_SDK_PORT
    HIKVISION_USERNAME
#>

param(
  [string]$DevicePassword = $env:HIKVISION_GATE_PASSWORD,
  [string]$DeviceAddress = $(if ($env:HIKVISION_MONITOR_IP) { $env:HIKVISION_MONITOR_IP } else { '192.168.1.84' }),
  [int]$DevicePort = $(if ($env:HIKVISION_SDK_PORT) { [int]$env:HIKVISION_SDK_PORT } else { 8000 }),
  [string]$DeviceUsername = $(if ($env:HIKVISION_USERNAME) { $env:HIKVISION_USERNAME } else { 'admin' })
)

if ([string]::IsNullOrWhiteSpace($DevicePassword)) {
  throw 'Set HIKVISION_GATE_PASSWORD before running this script.'
}

$diagnosticScript = Join-Path $PSScriptRoot 'hikvision-diagnose.ps1'
$powershell64 = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'

& $powershell64 -NoProfile -ExecutionPolicy Bypass -File $diagnosticScript `
  -DeviceAddress $DeviceAddress `
  -DevicePort $DevicePort `
  -DeviceUsername $DeviceUsername `
  -DevicePassword $DevicePassword `
  -OpenGate -AccessControlVariant

exit $LASTEXITCODE
