# Troubleshooting

These are the main problems encountered while moving the working bridge to a fresh Windows 11 x64 server.

## `L'esecuzione di script è disabilitata`

Run the script for that process with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\hikvision-open-gate.ps1
```

There is no need to permanently set the machine to `Unrestricted`.

## `BadImageFormatException` / `0x8007000B`

Typical cause: 32/64-bit mismatch.

The tested iVMS-4200 installation supplied an **x64** `HCNetSDK.dll`. Therefore the Hikvision SDK calls must run in **64-bit Windows PowerShell**:

```text
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```

Do **not** use the 32-bit copy under `SysWOW64` with this SDK.

Verify the process:

```powershell
[Environment]::Is64BitProcess
[IntPtr]::Size
```

Expected:

```text
True
8
```

## `SDK_ERROR=17` after `LOGIN_OK`

In the old x86 script the XML structures were packed with `Pack=1` and had a hard-coded size of `56` bytes. That is not correct for the x64 SDK because the structures contain pointers (`IntPtr`).

The repository version fixes this by:

- using natural structure alignment for `XmlConfigInput` / `XmlConfigOutput`;
- calculating `Size` with `Marshal.SizeOf()` at runtime.

## `Impossibile trovare il tipo [Security.Cryptography.ProtectedData]`

Windows PowerShell 5.1 may require the assembly to be loaded explicitly. The H24 scripts include:

```powershell
Add-Type -AssemblyName System.Security
```

## Scheduled task becomes `Ready`, result `1`, log says `SinricPro:INFO`

The Python SinricPro SDK can emit informational messages on STDERR. Windows PowerShell 5.1 may reinterpret native STDERR as an error when `$ErrorActionPreference = 'Stop'`.

The H24 runner avoids this by starting Python through `cmd.exe` and redirecting stdout + stderr directly to the log.

## `LOGIN_FAILED SDK_ERROR=...`

Check:

1. indoor monitor IP;
2. SDK port (tested: `8000`);
3. Hikvision username/password;
4. LAN reachability;
5. `HCNetSDK.dll` path;
6. Windows Firewall / endpoint security rules.

Quick network test:

```powershell
Test-NetConnection 192.168.1.84 -Port 8000
```

## `HCNetSDK.dll not found`

Tested path:

```text
C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client\HCNetSDK.dll
```

Search for it:

```powershell
Get-ChildItem 'C:\Program Files*' -Recurse -Filter HCNetSDK.dll -ErrorAction SilentlyContinue |
  Select-Object FullName
```

If it is installed elsewhere, set `HIKVISION_SDK_DIR` before running the scripts or change the default in `hikvision-diagnose.ps1`.

## Bridge connects but Google command does nothing

Check the log:

```powershell
Get-Content C:\Home-Domotica\Logs\sinric-bridge.log -Tail 100
```

Look for:

```text
SinricPro SDK initialized successfully
Bridge online. Say the Google routine command when ready.
```

Then verify that Google Home turns **ON** the Sinric Smart Switch configured with the same Device ID.

## Duplicate openings

The Python bridge has two safeguards:

- `HIKVISION_GATE_COOLDOWN` (default `10` seconds);
- `SINRICPRO_STARTUP_IGNORE` (default `8` seconds), which ignores a stale restored `ON` state just after bridge startup.

## Binary-looking characters in old logs

Some SDK responses from this intercom were not useful UTF-8 text. The current script no longer dumps the raw output/status buffers on a successful open command; it logs a clean `OPEN_COMMAND_ACCEPTED` instead.
