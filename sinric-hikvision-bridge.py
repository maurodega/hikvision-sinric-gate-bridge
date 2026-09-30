"""Sinric Pro -> Hikvision gate bridge.

The Sinric device is intentionally a momentary Smart Switch. Turning it on
runs the tested local Hikvision PowerShell command, then the bridge reports the
virtual switch off again.

Secrets are read only from environment variables.
"""

from __future__ import annotations

import asyncio
import os
import time
from pathlib import Path

from sinricpro import SinricPro, SinricProConfig, SinricProSwitch

ROOT = Path(__file__).resolve().parent
DEVICE_ID = os.environ.get("SINRICPRO_DEVICE_ID", "")
APP_KEY = os.environ.get("SINRICPRO_APP_KEY", "")
APP_SECRET = os.environ.get("SINRICPRO_APP_SECRET", "")
GATE_PASSWORD = os.environ.get("HIKVISION_GATE_PASSWORD", "")
COOLDOWN_SECONDS = float(os.environ.get("HIKVISION_GATE_COOLDOWN", "10"))
STARTUP_IGNORE_SECONDS = float(os.environ.get("SINRICPRO_STARTUP_IGNORE", "8"))

if not DEVICE_ID or not APP_KEY or not APP_SECRET:
    raise SystemExit(
        "Set SINRICPRO_DEVICE_ID, SINRICPRO_APP_KEY and SINRICPRO_APP_SECRET."
    )
if not GATE_PASSWORD:
    raise SystemExit("Set HIKVISION_GATE_PASSWORD.")

gate_lock = asyncio.Lock()
last_open = 0.0
started_at = time.monotonic()
switch: SinricProSwitch | None = None


async def open_gate() -> bool:
    """Run the tested PowerShell wrapper and return its result."""
    powershell = Path(os.environ.get("WINDIR", r"C:\Windows")) / (
        "System32/WindowsPowerShell/v1.0/powershell.exe"
    )
    command = [
        str(powershell),
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        str(ROOT / "hikvision-open-gate.ps1"),
    ]

    process = await asyncio.create_subprocess_exec(
        *command,
        cwd=str(ROOT),
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.STDOUT,
        env=os.environ.copy(),
    )

    try:
        output, _ = await asyncio.wait_for(process.communicate(), timeout=20)
    except asyncio.TimeoutError:
        process.kill()
        await process.communicate()
        print("Hikvision command timed out", flush=True)
        return False

    text = output.decode(errors="replace").replace("\x00", "").strip()
    if text:
        print(f"Hikvision output: {text}", flush=True)

    return (
        process.returncode == 0
        and "LOGIN_OK" in text
        and "OPEN_COMMAND_FAILED" not in text
    )


async def on_power_state(state: bool) -> bool:
    """Handle the Sinric Smart Switch command."""
    global last_open

    if not state:
        return True

    # Do not let a cloud-restored stale ON state open the gate at startup.
    if time.monotonic() - started_at < STARTUP_IGNORE_SECONDS:
        print("Ignoring a startup-restored ON state", flush=True)
        return True

    now = time.monotonic()
    if now - last_open < COOLDOWN_SECONDS:
        print("Ignoring duplicate gate command during cooldown", flush=True)
        return True

    async with gate_lock:
        last_open = time.monotonic()
        success = await open_gate()
        if success and switch is not None:
            # The physical action is momentary; keep the virtual switch OFF.
            await switch.send_power_state_event(False)
        return success


async def main() -> None:
    global switch

    sinric = SinricPro.get_instance()
    switch = SinricProSwitch(DEVICE_ID)
    switch.on_power_state(on_power_state)
    sinric.add(switch)

    config = SinricProConfig(
        app_key=APP_KEY,
        app_secret=APP_SECRET,
        local_control=False,
    )

    print("Connecting to Sinric Pro...", flush=True)
    await sinric.begin(config)
    print("Bridge online. Say the Google routine command when ready.", flush=True)

    try:
        while True:
            await asyncio.sleep(1)
    finally:
        await sinric.stop()


if __name__ == "__main__":
    asyncio.run(main())
