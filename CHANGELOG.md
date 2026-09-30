# Changelog

## 1.0.0 - 2026-09-28

- Verified gate opening through Hikvision indoor monitor `DS-KH6320-WTE1/EU`.
- Verified Google Home -> Sinric Pro -> Python -> HCNetSDK -> gate flow.
- Migrated the Hikvision SDK integration from the old x86 assumptions to x64.
- Replaced hard-coded XML structure sizes with runtime `Marshal.SizeOf()`.
- Removed `Pack=1` from XML structures containing pointers.
- Added automatic H24 startup through Windows Task Scheduler as `SYSTEM`.
- Added DPAPI-protected credential storage outside the repository.
- Added automatic restart on bridge failure and persistent log output.
- Fixed PowerShell 5.1 `ProtectedData` assembly loading.
- Fixed SinricPro informational STDERR being mistaken for a fatal PowerShell error.
- Stopped dumping binary-looking HCNetSDK response bytes into normal logs.
