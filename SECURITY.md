# Security notes

This project can trigger a physical gate. Treat it as an automation convenience layer, not as a safety- or security-critical control.

## Secrets

Never commit or paste these values into GitHub issues, screenshots or logs:

- `SINRICPRO_APP_SECRET`
- `HIKVISION_GATE_PASSWORD`
- any filled-in local environment file
- the generated DPAPI file from `C:\Home-Domotica\Config`

`SINRICPRO_DEVICE_ID` and `SINRICPRO_APP_KEY` are also intentionally omitted from this repository template.

The H24 setup stores credentials outside the repository in:

```text
C:\Home-Domotica\Config\hikvision-sinric.dpapi.json
```

The values are protected with Windows DPAPI (`LocalMachine`) and the file ACL is restricted to `SYSTEM` and local Administrators.

## Network

- Keep the Hikvision SDK port reachable only from trusted LAN hosts.
- Do not expose port `8000` or the intercom HTTP interface directly to the Internet.
- Prefer a dedicated Hikvision account with the minimum permissions needed, if the device/firmware supports it.
- Keep Windows, Python, iVMS-4200/HCNetSDK and device firmware maintained.

## Voice / cloud control

The voice path depends on Internet connectivity plus Google Home and Sinric Pro cloud availability. Do not make it the only way to enter, exit, or operate a safety-critical mechanism.

## If a secret is committed

Do not merely delete the file from the latest Git commit. Rotate the affected credential and remove it from Git history before considering the repository clean.
