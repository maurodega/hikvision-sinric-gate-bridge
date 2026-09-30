#requires -version 5.1
# Launcher H24: decifra le credenziali DPAPI, imposta le variabili solo nel processo
# e mantiene il bridge Python sotto il controllo di Utilita di pianificazione.

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1: ProtectedData vive nell'assembly System.Security.
Add-Type -AssemblyName System.Security

$ProjectDir = 'C:\Home-Domotica\Hikvision'
$ConfigPath = 'C:\Home-Domotica\Config\hikvision-sinric.dpapi.json'
$LogDir = 'C:\Home-Domotica\Logs'
$LogPath = Join-Path $LogDir 'sinric-bridge.log'
$PythonPath = 'C:\Home-Domotica\Python\python.exe'
$BridgePath = Join-Path $ProjectDir 'sinric-hikvision-bridge.py'

function Unprotect-TextLocalMachine([string]$Base64) {
    $protected = [Convert]::FromBase64String($Base64)
    try {
        $plain = [System.Security.Cryptography.ProtectedData]::Unprotect(
            $protected,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        try {
            return [Text.Encoding]::UTF8.GetString($plain)
        }
        finally {
            if ($plain) { [Array]::Clear($plain, 0, $plain.Length) }
        }
    }
    finally {
        if ($protected) { [Array]::Clear($protected, 0, $protected.Length) }
    }
}

function Write-BridgeLog([string]$Message) {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Add-Content -LiteralPath $LogPath -Value "[$stamp] $Message" -Encoding UTF8
}

try {
    if (-not (Test-Path -LiteralPath $ConfigPath)) {
        throw "File configurazione non trovato: $ConfigPath"
    }
    if (-not (Test-Path -LiteralPath $PythonPath)) {
        throw "Python non trovato: $PythonPath"
    }
    if (-not (Test-Path -LiteralPath $BridgePath)) {
        throw "Bridge Python non trovato: $BridgePath"
    }

    $config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

    $env:SINRICPRO_DEVICE_ID = Unprotect-TextLocalMachine $config.sinricDeviceId
    $env:SINRICPRO_APP_KEY = Unprotect-TextLocalMachine $config.sinricAppKey
    $env:SINRICPRO_APP_SECRET = Unprotect-TextLocalMachine $config.sinricAppSecret
    $env:HIKVISION_GATE_PASSWORD = Unprotect-TextLocalMachine $config.hikvisionPassword

    $env:HIKVISION_GATE_COOLDOWN = '10'
    $env:SINRICPRO_STARTUP_IGNORE = '8'

    Set-Location -LiteralPath $ProjectDir
    Write-BridgeLog 'Avvio bridge Sinric Pro -> Hikvision.'

    # IMPORTANTE:
    # In Windows PowerShell 5.1 l'output STDERR di un programma nativo puo essere
    # trasformato in ErrorRecord. La libreria SinricPro scrive messaggi INFO su
    # STDERR; con ErrorActionPreference=Stop il vecchio launcher li scambiava per
    # errori e terminava immediatamente.
    #
    # Eseguiamo quindi Python tramite cmd.exe, che accorpa stdout+stderr nel log
    # senza farli reinterpretare da PowerShell.
    $quotedPython = '"' + $PythonPath + '"'
    $quotedBridge = '"' + $BridgePath + '"'
    $quotedLog = '"' + $LogPath + '"'
    $cmdLine = "$quotedPython $quotedBridge >> $quotedLog 2>&1"

    & "$env:WINDIR\System32\cmd.exe" /d /s /c $cmdLine
    $exitCode = $LASTEXITCODE

    if ($null -eq $exitCode -or $exitCode -eq 0) {
        Write-BridgeLog 'Bridge terminato inaspettatamente con exit code 0. Forzo exit 1 per il riavvio automatico.'
        exit 1
    }

    Write-BridgeLog "Bridge terminato con exit code $exitCode."
    exit $exitCode
}
catch {
    Write-BridgeLog ("ERRORE launcher: " + $_.Exception.Message)
    exit 1
}
finally {
    Remove-Item Env:\SINRICPRO_DEVICE_ID -ErrorAction SilentlyContinue
    Remove-Item Env:\SINRICPRO_APP_KEY -ErrorAction SilentlyContinue
    Remove-Item Env:\SINRICPRO_APP_SECRET -ErrorAction SilentlyContinue
    Remove-Item Env:\HIKVISION_GATE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:\HIKVISION_GATE_COOLDOWN -ErrorAction SilentlyContinue
    Remove-Item Env:\SINRICPRO_STARTUP_IGNORE -ErrorAction SilentlyContinue
}
