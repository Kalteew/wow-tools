from __future__ import annotations

import atexit
import os
import subprocess
import socket
import time
import tempfile
from pathlib import Path

from wow_tools.gui import main

_PID_FILE = Path(tempfile.gettempdir()) / "wow_tools_gui.pid"
_GUI_SINGLE_INSTANCE_HOST = "127.0.0.1"
_GUI_SINGLE_INSTANCE_PORT = 46321


def _kill_pid(pid: int) -> None:
    if pid <= 0 or pid == os.getpid():
        return
    subprocess.run(
        ["taskkill", "/PID", str(pid), "/F"],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _kill_matching_previous_instances() -> None:
    current_pid = os.getpid()
    script_path = str(Path(__file__).resolve())
    ps_script = f"""
$currentPid = {current_pid}
$scriptPath = "{script_path}"
Get-CimInstance Win32_Process |
    Where-Object {{
        $_.ProcessId -ne $currentPid -and
        $_.Name -eq 'pythonw.exe' -and
        $_.CommandLine -like "*$scriptPath*"
    }} |
    ForEach-Object {{
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }}
"""
    subprocess.run(
        ["powershell", "-NoProfile", "-Command", ps_script],
        check=False,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def _cleanup_pid_file() -> None:
    try:
        if _PID_FILE.exists() and _PID_FILE.read_text(encoding="utf-8").strip() == str(os.getpid()):
            _PID_FILE.unlink()
    except OSError:
        pass


def _close_previous_instance() -> None:
    _request_previous_instance_shutdown()

    try:
        previous_pid = int(_PID_FILE.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        previous_pid = 0

    _kill_pid(previous_pid)
    _kill_matching_previous_instances()
    time.sleep(0.4)
    current_pid = os.getpid()
    _PID_FILE.write_text(str(current_pid), encoding="utf-8")
    atexit.register(_cleanup_pid_file)


def _request_previous_instance_shutdown() -> None:
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.settimeout(0.2)
    try:
        client.connect((_GUI_SINGLE_INSTANCE_HOST, _GUI_SINGLE_INSTANCE_PORT))
        client.sendall(b"shutdown")
    except OSError:
        pass
    finally:
        try:
            client.close()
        except OSError:
            pass


if __name__ == "__main__":
    _close_previous_instance()
    main()
