#requires -version 5.1
# Configura il bridge Hikvision/Sinric Pro per l'avvio H24 come attivita pianificata SYSTEM.
# Eseguire UNA VOLTA da Windows PowerShell "Esegui come amministratore".

$ErrorActionPreference = 'Stop'

# Windows PowerShell 5.1: ProtectedData vive nell'assembly System.Security.
Add-Type -AssemblyName System.Security

$ProjectDir = 'C:\Home-Domotica\Hikvision'
$ConfigDir  = 'C:\Home-Domotica\Config'
$LogDir     = 'C:\Home-Domotica\Logs'
$ConfigPath = Join-Path $ConfigDir 'hikvision-sinric.dpapi.json'
$RunnerPath = Join-Path $ProjectDir 'run-sinric-bridge-h24.ps1'
$PythonPath = 'C:\Home-Domotica\Python\python.exe'
$BridgePath = Join-Path $ProjectDir 'sinric-hikvision-bridge.py'
$TaskName   = 'Home-Domotica - Hikvision Sinric Bridge'

function Assert-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Apri Windows PowerShell con "Esegui come amministratore" e rilancia questo script.'
    }
}

function Convert-SecureStringToPlainText([Security.SecureString]$Value) {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    }
    finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
    }
}

function Protect-TextLocalMachine([string]$Text) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    try {
        $protected = [System.Security.Cryptography.ProtectedData]::Protect(
            $bytes,
            $null,
            [System.Security.Cryptography.DataProtectionScope]::LocalMachine
        )
        return [Convert]::ToBase64String($protected)
    }
    finally {
        if ($bytes) { [Array]::Clear($bytes, 0, $bytes.Length) }
    }
}

function Protect-ConfigFileAcl([string]$Path) {
    # Accesso al file: solo SYSTEM e gruppo Administrators.
    $acl = New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true, $false)

    $systemSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-18')
    $adminsSid = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')

    $noneI = [Security.AccessControl.InheritanceFlags]::None
    $noneP = [Security.AccessControl.PropagationFlags]::None
    $allow = [Security.AccessControl.AccessControlType]::Allow

    $systemRule = New-Object Security.AccessControl.FileSystemAccessRule(
        $systemSid,
        [Security.AccessControl.FileSystemRights]::Read,
        $noneI,
        $noneP,
        $allow
    )
    $adminsRule = New-Object Security.AccessControl.FileSystemAccessRule(
        $adminsSid,
        [Security.AccessControl.FileSystemRights]::FullControl,
        $noneI,
        $noneP,
        $allow
    )

    [void]$acl.AddAccessRule($systemRule)
    [void]$acl.AddAccessRule($adminsRule)
    Set-Acl -LiteralPath $Path -AclObject $acl
}

Assert-Administrator

foreach ($path in @($ProjectDir, $PythonPath, $BridgePath, $RunnerPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Percorso/file mancante: $path"
    }
}

New-Item -ItemType Directory -Force -Path $ConfigDir, $LogDir | Out-Null

Write-Host ''
Write-Host '=== Configurazione bridge Hikvision / Sinric Pro H24 ===' -ForegroundColor Cyan
Write-Host 'Le credenziali verranno cifrate con Windows DPAPI (LocalMachine).' -ForegroundColor DarkGray
Write-Host 'Nel progetto/shared folder non verra salvata alcuna password in chiaro.' -ForegroundColor DarkGray
Write-Host ''

$deviceId = Read-Host 'Sinric Device ID'
$appKey   = Read-Host 'Sinric App Key'
$appSecretSecure = Read-Host 'Sinric App Secret' -AsSecureString
$hikSecretSecure = Read-Host 'Password Hikvision' -AsSecureString

$appSecretPlain = Convert-SecureStringToPlainText $appSecretSecure
$hikSecretPlain = Convert-SecureStringToPlainText $hikSecretSecure

try {
    $payload = [ordered]@{
        version            = 1
        createdAt          = (Get-Date).ToString('o')
        sinricDeviceId     = Protect-TextLocalMachine $deviceId
        sinricAppKey       = Protect-TextLocalMachine $appKey
        sinricAppSecret    = Protect-TextLocalMachine $appSecretPlain
        hikvisionPassword  = Protect-TextLocalMachine $hikSecretPlain
    }

    $payload | ConvertTo-Json | Set-Content -LiteralPath $ConfigPath -Encoding UTF8
    Protect-ConfigFileAcl $ConfigPath
}
finally {
    $appSecretPlain = $null
    $hikSecretPlain = $null
    $appSecretSecure = $null
    $hikSecretSecure = $null
}

$psExe = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$RunnerPath`""

$action = New-ScheduledTaskAction `
    -Execute $psExe `
    -Argument $arguments `
    -WorkingDirectory $ProjectDir

$trigger = New-ScheduledTaskTrigger -AtStartup
try { $trigger.Delay = 'PT30S' } catch {}

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 999 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -MultipleInstances IgnoreNew

$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description 'Bridge H24 Sinric Pro -> Hikvision gate' `
    -Force | Out-Null

Start-ScheduledTask -TaskName $TaskName

Start-Sleep -Seconds 3

$task = Get-ScheduledTask -TaskName $TaskName
$info = Get-ScheduledTaskInfo -TaskName $TaskName

Write-Host ''
Write-Host 'CONFIGURAZIONE COMPLETATA' -ForegroundColor Green
Write-Host "Task:        $TaskName"
Write-Host "Stato:       $($task.State)"
Write-Host "Ultimo esito: $($info.LastTaskResult)"
Write-Host "Config:      $ConfigPath"
Write-Host "Log:         $LogDir\sinric-bridge.log"
Write-Host ''
Write-Host 'Ora prova il comando Google Home. Non avviare contemporaneamente il bridge interattivo.' -ForegroundColor Yellow
