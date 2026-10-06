#requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

$WatchdogScript = 'C:\Home-Domotica\Hikvision\watchdog-sinric.ps1'
$WatchdogTask = 'Home-Domotica - Sinric Watchdog'

if (-not (Test-Path -LiteralPath $WatchdogScript)) {
    throw "File non trovato: $WatchdogScript"
}

$ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$command = "`"$ps`" -NoProfile -ExecutionPolicy Bypass -File `"$WatchdogScript`""

schtasks.exe /Create `
    /TN $WatchdogTask `
    /SC MINUTE `
    /MO 5 `
    /TR $command `
    /RU SYSTEM `
    /RL HIGHEST `
    /F | Out-Host

Write-Host ''
Write-Host 'Watchdog installato.' -ForegroundColor Green
Write-Host "Task: $WatchdogTask"
Write-Host 'Frequenza: ogni 5 minuti'
Write-Host 'Log: C:\Home-Domotica\Logs\sinric-watchdog.log'
Write-Host ''
Write-Host 'Avvio subito un primo controllo...'
Start-ScheduledTask -TaskName $WatchdogTask
