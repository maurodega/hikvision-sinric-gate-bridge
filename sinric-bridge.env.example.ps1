# Example only. DO NOT commit a filled-in copy.
# These variables live only in the current PowerShell process.

$env:SINRICPRO_DEVICE_ID = ""
$env:SINRICPRO_APP_KEY = ""
$env:SINRICPRO_APP_SECRET = ""
$env:HIKVISION_GATE_PASSWORD = ""

# Optional Hikvision overrides. Defaults match the tested installation.
$env:HIKVISION_MONITOR_IP = "192.168.1.84"
$env:HIKVISION_SDK_PORT = "8000"
$env:HIKVISION_USERNAME = "admin"
$env:HIKVISION_SDK_DIR = "C:\Program Files (x86)\iVMS-4200 Site\iVMS-4200 Client\Client"

# Optional bridge protections.
$env:HIKVISION_GATE_COOLDOWN = "10"
$env:SINRICPRO_STARTUP_IGNORE = "8"
