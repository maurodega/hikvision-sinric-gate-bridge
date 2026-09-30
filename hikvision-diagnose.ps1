param(
  [string]$DevicePassword,
  [string]$DeviceAddress = '192.168.1.84',
  [int]$DevicePort = 8000,
  [string]$DeviceUsername = 'admin',
  [switch]$OpenGate,
  [switch]$DirectGateway,
  [switch]$AccessControlVariant,
  [switch]$LoginV40,
  [switch]$LoginOnly
)

$ErrorActionPreference = 'Stop'
$sdkDirectory = if ($env:HIKVISION_SDK_DIR) {
  $env:HIKVISION_SDK_DIR
} else {
  'C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client'
}

if (-not [Environment]::Is64BitProcess) {
  throw 'This project expects the x64 HCNetSDK and must run in 64-bit Windows PowerShell (System32), not SysWOW64.'
}

$sdkDll = Join-Path $sdkDirectory 'HCNetSDK.dll'
if (-not (Test-Path -LiteralPath $sdkDll)) {
  throw "HCNetSDK.dll not found at: $sdkDll"
}

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class HikDiagnostic {
 [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
 public struct LoginInfo {
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=129)] public string Address;
  public byte UseTransport;
  public ushort Port;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string Username;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=64)] public string Password;
  public IntPtr Callback;
  public IntPtr User;
  public int Async;
  public byte ProxyType, UseUTC, LoginMode, Https;
  public int ProxyId;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=120)] public byte[] Reserved;
 }
 [StructLayout(LayoutKind.Sequential, Pack=1)]
 public struct ControlGateway {
  public uint Size;
  public uint GatewayIndex;
  public byte Command;
  public byte LockType;
  public ushort LockID;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string ControlSource;
  public byte ControlType;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=3)] public byte[] Reserved3;
  [MarshalAs(UnmanagedType.ByValTStr, SizeConst=16)] public string Password;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=108)] public byte[] Reserved2;
 }
 [StructLayout(LayoutKind.Sequential)]
 public struct XmlConfigInput {
  public uint Size;
  public IntPtr RequestUrl;
  public uint RequestUrlLen;
  public IntPtr InBuffer;
  public uint InBufferSize;
  public uint ReceiveTimeout;
  public byte ForceEncrypt;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=31)] public byte[] Reserved;
 }
 [StructLayout(LayoutKind.Sequential)]
 public struct XmlConfigOutput {
  public uint Size;
  public IntPtr OutBuffer;
  public uint OutBufferSize;
  public uint ReturnedXmlSize;
  public IntPtr StatusBuffer;
  public uint StatusSize;
  [MarshalAs(UnmanagedType.ByValArray, SizeConst=32)] public byte[] Reserved;
 }
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode)] public static extern bool SetDllDirectory(string path);
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_Init();
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_SetConnectTime(uint timeout, uint attempts);
 [DllImport("HCNetSDK.dll", CharSet=CharSet.Ansi)] public static extern int NET_DVR_Login_V30(string address, ushort port, string user, string password, IntPtr info);
 [DllImport("HCNetSDK.dll")] public static extern int NET_DVR_Login_V40(ref LoginInfo login, IntPtr info);
 [DllImport("HCNetSDK.dll")] public static extern uint NET_DVR_GetLastError();
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_RemoteControl(int user, uint command, ref ControlGateway control, uint controlSize);
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_STDXMLConfig(int user, ref XmlConfigInput input, ref XmlConfigOutput output);
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_Logout(int user);
 [DllImport("HCNetSDK.dll")] public static extern bool NET_DVR_Cleanup();
}
'@

[void][HikDiagnostic]::SetDllDirectory($sdkDirectory)
Set-Location -LiteralPath $sdkDirectory

$infoBuffer = [Runtime.InteropServices.Marshal]::AllocHGlobal(1024)
$loginId = -1
$scriptExitCode = 0

try {
  if (-not [HikDiagnostic]::NET_DVR_Init()) {
    throw 'SDK initialization failed.'
  }

  [void][HikDiagnostic]::NET_DVR_SetConnectTime(5000, 1)

  if ($LoginV40) {
    $loginData = New-Object HikDiagnostic+LoginInfo
    $loginData.Address = $DeviceAddress
    $loginData.Port = [ushort]$DevicePort
    $loginData.Username = $DeviceUsername
    $loginData.Password = $DevicePassword
    $loginData.Reserved = New-Object byte[] 120
    $loginId = [HikDiagnostic]::NET_DVR_Login_V40([ref]$loginData, $infoBuffer)
  }
  else {
    $loginId = [HikDiagnostic]::NET_DVR_Login_V30(
      $DeviceAddress,
      [ushort]$DevicePort,
      $DeviceUsername,
      $DevicePassword,
      $infoBuffer
    )
  }

  if ($loginId -lt 0) {
    Write-Output ('LOGIN_FAILED SDK_ERROR=' + [HikDiagnostic]::NET_DVR_GetLastError())
    $scriptExitCode = 10
  }
  elseif ($LoginOnly) {
    Write-Output 'LOGIN_OK (read-only connection; no opening command sent)'
  }
  elseif ($OpenGate) {
    Write-Output 'LOGIN_OK'

    if ($DirectGateway) {
      $control = New-Object HikDiagnostic+ControlGateway
      $control.Size = 172
      $control.GatewayIndex = 1
      $control.Command = 1
      $control.LockType = 0
      $control.LockID = 0
      $control.ControlSource = 'PowerShell'
      $control.ControlType = 1
      $control.Reserved3 = New-Object byte[] 3
      $control.Password = ''
      $control.Reserved2 = New-Object byte[] 108

      if ([HikDiagnostic]::NET_DVR_RemoteControl($loginId, 16009, [ref]$control, 172)) {
        Write-Output 'OPEN_COMMAND_ACCEPTED (direct gateway; physical opening not verified)'
      }
      else {
        Write-Output ('OPEN_COMMAND_FAILED SDK_ERROR=' + [HikDiagnostic]::NET_DVR_GetLastError())
        $scriptExitCode = 20
      }
    }
    else {
      if ($AccessControlVariant) {
        $requestUrlBytes = [Text.Encoding]::ASCII.GetBytes("PUT /ISAPI/AccessControl/RemoteControl/door/1`r`n")
        $requestBodyBytes = [Text.Encoding]::UTF8.GetBytes('<RemoteControlDoor version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema"><channelNo>1</channelNo><cmd>open</cmd><controlType>monitor</controlType></RemoteControlDoor>')
      }
      else {
        $requestUrlBytes = [Text.Encoding]::ASCII.GetBytes("PUT /ISAPI/VideoIntercom/remoteOpenDoor`r`n")
        $requestBodyBytes = [Text.Encoding]::UTF8.GetBytes('<RemoteOpenDoor version="2.0" xmlns="http://www.isapi.org/ver20/XMLSchema"><gateWayIndex>1</gateWayIndex><command>unlock</command><controlSrc>PowerShell</controlSrc></RemoteOpenDoor>')
      }

      $requestUrlPtr = [Runtime.InteropServices.Marshal]::AllocHGlobal($requestUrlBytes.Length)
      $requestBodyPtr = [Runtime.InteropServices.Marshal]::AllocHGlobal($requestBodyBytes.Length)
      $outputPtr = [Runtime.InteropServices.Marshal]::AllocHGlobal(8192)
      $statusPtr = [Runtime.InteropServices.Marshal]::AllocHGlobal(4096)

      try {
        [Runtime.InteropServices.Marshal]::Copy($requestUrlBytes, 0, $requestUrlPtr, $requestUrlBytes.Length)
        [Runtime.InteropServices.Marshal]::Copy($requestBodyBytes, 0, $requestBodyPtr, $requestBodyBytes.Length)

        $xmlInput = New-Object HikDiagnostic+XmlConfigInput
        $xmlInput.Size = [Runtime.InteropServices.Marshal]::SizeOf($xmlInput)
        $xmlInput.RequestUrl = $requestUrlPtr
        $xmlInput.RequestUrlLen = $requestUrlBytes.Length
        $xmlInput.InBuffer = $requestBodyPtr
        $xmlInput.InBufferSize = $requestBodyBytes.Length
        $xmlInput.ReceiveTimeout = 5000
        $xmlInput.ForceEncrypt = 0
        $xmlInput.Reserved = New-Object byte[] 31

        $xmlOutput = New-Object HikDiagnostic+XmlConfigOutput
        $xmlOutput.Size = [Runtime.InteropServices.Marshal]::SizeOf($xmlOutput)
        $xmlOutput.OutBuffer = $outputPtr
        $xmlOutput.OutBufferSize = 8192
        $xmlOutput.ReturnedXmlSize = 0
        $xmlOutput.StatusBuffer = $statusPtr
        $xmlOutput.StatusSize = 4096
        $xmlOutput.Reserved = New-Object byte[] 32

        if ([HikDiagnostic]::NET_DVR_STDXMLConfig($loginId, [ref]$xmlInput, [ref]$xmlOutput)) {
          # The SDK may return non-text bytes in the output buffer on this intercom.
          # Avoid dumping binary-looking data to stdout; the native call itself succeeded.
          Write-Output 'OPEN_COMMAND_ACCEPTED (ISAPI tunnel; physical opening not verified)'
        }
        else {
          Write-Output ('OPEN_COMMAND_FAILED SDK_ERROR=' + [HikDiagnostic]::NET_DVR_GetLastError())
          $scriptExitCode = 20
        }
      }
      finally {
        [Runtime.InteropServices.Marshal]::FreeHGlobal($requestUrlPtr)
        [Runtime.InteropServices.Marshal]::FreeHGlobal($requestBodyPtr)
        [Runtime.InteropServices.Marshal]::FreeHGlobal($outputPtr)
        [Runtime.InteropServices.Marshal]::FreeHGlobal($statusPtr)
      }
    }
  }
  else {
    Write-Output 'LOGIN_OK (read-only connection; no opening command sent)'
  }
}
catch {
  Write-Output ('ERROR: ' + $_.Exception.Message)
  $scriptExitCode = 99
}
finally {
  if ($loginId -ge 0) {
    [void][HikDiagnostic]::NET_DVR_Logout($loginId)
  }
  [void][HikDiagnostic]::NET_DVR_Cleanup()
  [Runtime.InteropServices.Marshal]::FreeHGlobal($infoBuffer)
}

exit $scriptExitCode
