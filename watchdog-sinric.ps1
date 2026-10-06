# Sinric/Hikvision watchdog v2
# Controlla lo stato reale del bridge usando task/processo + log Sinric.
# Se dopo l'ultimo avvio del bridge compare un errore di reconnessione definitivo,
# riavvia il task H24.

$ErrorActionPreference = 'SilentlyContinue'

$BridgeTask = 'Home-Domotica - Hikvision Sinric Bridge'
$BridgeScriptName = 'sinric-hikvision-bridge.py'
$BridgeLog = 'C:\Home-Domotica\Logs\sinric-bridge.log'
$WatchdogLog = 'C:\Home-Domotica\Logs\sinric-watchdog.log'

function Write-WatchdogLog([string]$Message) {
    $dir = Split-Path -Parent $WatchdogLog
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $WatchdogLog -Value "[$stamp] $Message" -Encoding UTF8
}

function Restart-Bridge([string]$Reason) {
    Write-WatchdogLog "Riavvio bridge: $Reason"
    Stop-ScheduledTask -TaskName $BridgeTask -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-ScheduledTask -TaskName $BridgeTask -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
}

$task = Get-ScheduledTask -TaskName $BridgeTask -ErrorAction SilentlyContinue
if (-not $task) {
    Write-WatchdogLog "ERRORE: task '$BridgeTask' non trovato."
    exit 1
}

if ($task.State -ne 'Running') {
    Restart-Bridge "task non Running (stato: $($task.State))"
    exit 0
}

$bridgeProcesses = Get-CimInstance Win32_Process | Where-Object {
    $_.Name -ieq 'python.exe' -and
    $_.CommandLine -like "*$BridgeScriptName*"
}

if (-not $bridgeProcesses) {
    Restart-Bridge "processo Python del bridge non trovato"
    exit 0
}

if (Test-Path -LiteralPath $BridgeLog) {
    $lines = @(Get-Content -LiteralPath $BridgeLog -Tail 500)

    $lastStart = -1
    $lastFatal = -1
    $fatalReason = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]

        if ($line -match 'Avvio bridge Sinric Pro -> Hikvision') {
            $lastStart = $i
        }

        if (
            $line -match 'Reconnection failed' -or
            $line -match 'WebSocket connection failed:.*getaddrinfo failed' -or
            $line -match 'WebSocket error:.*getaddrinfo failed'
        ) {
            $lastFatal = $i
            $fatalReason = $line.Trim()
        }
    }

    if ($lastFatal -gt $lastStart) {
        Restart-Bridge "Sinric offline dopo l'ultimo avvio: $fatalReason"
        exit 0
    }
}

exit 0
