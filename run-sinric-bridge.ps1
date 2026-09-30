param(
  [string]$Python = 'C:\Home-Domotica\Python\python.exe'
)

$required = @(
  'SINRICPRO_DEVICE_ID',
  'SINRICPRO_APP_KEY',
  'SINRICPRO_APP_SECRET',
  'HIKVISION_GATE_PASSWORD'
)

foreach ($name in $required) {
  if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name, 'Process'))) {
    throw "Set `$env:$name before starting the bridge."
  }
}

if (-not (Test-Path -LiteralPath $Python)) {
  throw "Python executable not found: $Python"
}

& $Python (Join-Path $PSScriptRoot 'sinric-hikvision-bridge.py')
exit $LASTEXITCODE
