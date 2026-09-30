$TaskName = 'Home-Domotica - Hikvision Sinric Bridge'
$LogPath = 'C:\Home-Domotica\Logs\sinric-bridge.log'

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if (-not $task) {
  Write-Host "Task not found: $TaskName" -ForegroundColor Yellow
  exit 1
}

$info = Get-ScheduledTaskInfo -TaskName $TaskName

[PSCustomObject]@{
  TaskName = $TaskName
  State = $task.State
  LastRunTime = $info.LastRunTime
  LastTaskResult = $info.LastTaskResult
  NextRunTime = $info.NextRunTime
} | Format-List

if (Test-Path -LiteralPath $LogPath) {
  Write-Host ''
  Write-Host '--- Last 30 log lines ---' -ForegroundColor Cyan
  Get-Content -LiteralPath $LogPath -Tail 30
}
