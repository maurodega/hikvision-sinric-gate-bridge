# Prompts for credentials at runtime; nothing is written to disk.
$env:SINRICPRO_DEVICE_ID = Read-Host 'Sinric Device ID'
$env:SINRICPRO_APP_KEY = Read-Host 'Sinric App Key'
$sinricSecret = Read-Host 'Sinric App Secret' -AsSecureString
$hikSecret = Read-Host 'Hikvision device password' -AsSecureString

function Convert-SecureStringToPlainText([Security.SecureString]$Value) {
  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

$env:SINRICPRO_APP_SECRET = Convert-SecureStringToPlainText $sinricSecret
$env:HIKVISION_GATE_PASSWORD = Convert-SecureStringToPlainText $hikSecret

& (Join-Path $PSScriptRoot 'run-sinric-bridge.ps1')
exit $LASTEXITCODE
