# Removes only the scheduled task created by this project.
# It does not delete the project files or the encrypted credential file.

$TaskName = 'Home-Domotica - Hikvision Sinric Bridge'

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
  Write-Host "Scheduled task removed: $TaskName"
}
else {
  Write-Host "Scheduled task not found: $TaskName"
}

Write-Host 'Encrypted config, if present, is still in C:\Home-Domotica\Config\hikvision-sinric.dpapi.json'
