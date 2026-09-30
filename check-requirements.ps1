$ErrorActionPreference = 'Continue'

$python = 'C:\Home-Domotica\Python\python.exe'
$sdkDir = if ($env:HIKVISION_SDK_DIR) {
  $env:HIKVISION_SDK_DIR
} else {
  'C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client'
}
$sdk = Join-Path $sdkDir 'HCNetSDK.dll'
$monitorIp = if ($env:HIKVISION_MONITOR_IP) { $env:HIKVISION_MONITOR_IP } else { '192.168.1.84' }
$monitorPort = if ($env:HIKVISION_SDK_PORT) { [int]$env:HIKVISION_SDK_PORT } else { 8000 }

function Result($Name, $Ok, $Detail) {
  $status = if ($Ok) { 'OK' } else { 'FAIL' }
  [PSCustomObject]@{ Check = $Name; Status = $status; Detail = $Detail }
}

$results = @()
$results += Result '64-bit PowerShell' ([Environment]::Is64BitProcess) ("Is64BitProcess=" + [Environment]::Is64BitProcess)
$results += Result 'Python executable' (Test-Path -LiteralPath $python) $python
$results += Result 'HCNetSDK.dll' (Test-Path -LiteralPath $sdk) $sdk

if (Test-Path -LiteralPath $python) {
  $pyver = & $python --version 2>&1 | Out-String
  $results += Result 'Python version' ($LASTEXITCODE -eq 0) $pyver.Trim()

  & $python -c "import sinricpro; print('sinricpro import OK')" *> $null
  $results += Result 'Python sinricpro module' ($LASTEXITCODE -eq 0) 'python -c "import sinricpro"'
}

$portTest = Test-NetConnection -ComputerName $monitorIp -Port $monitorPort -WarningAction SilentlyContinue
$results += Result 'Hikvision monitor SDK port' $portTest.TcpTestSucceeded ("${monitorIp}:$monitorPort")

$results | Format-Table -AutoSize
