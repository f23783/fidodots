#!/usr/bin/env python3
"""
Video wallpaper otomatik duraklatıcı.

mpvpaper'ın kendi --auto-pause'u yalnızca TAM EKRAN pencerede çalışır (man mpvpaper:
"mpvpaper will still draw/render even if there is a normal window blocking the
wallpaper view entirely"). Tiling kullanan biri için işe yaramaz.

Bu betik Hyprland'in olay soketini (.socket2.sock) dinler ve her monitör için
"aktif workspace'te pencere var mı" sorusuna göre o monitörün mpv'sini
duraklatır/devam ettirir. Polling yok, olay tabanlı.

mpvpaper şu seçenekle başlatılmalı:
    -o "... input-ipc-server=$XDG_RUNTIME_DIR/mpvpaper-<MONITOR>.sock"
"""
import json
import os
import socket
import subprocess
import sys
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
HIS = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")

# Bu olaylardan sonra durum yeniden hesaplanır.
RELEVANT = (
    "workspace>>", "focusedmon>>", "openwindow>>", "closewindow>>",
    "movewindow>>", "fullscreen>>", "monitoradded>>", "monitorremoved>>",
    "activewindow>>", "changefloatingmode>>",
)

_last = {}   # monitör -> en son gönderilen pause değeri


def hypr(cmd):
    try:
        out = subprocess.run(
            ["hyprctl", "-j", cmd], capture_output=True, text=True, timeout=5
        )
        return json.loads(out.stdout) if out.returncode == 0 else None
    except Exception:
        return None


def mpv_set_pause(monitor, paused):
    """mpv IPC soketine pause komutu gönder."""
    if _last.get(monitor) == paused:
        return                      # gereksiz trafiği önle
    path = os.path.join(RUNTIME, "mpvpaper-%s.sock" % monitor)
    if not os.path.exists(path):
        return
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(2)
        s.connect(path)
        payload = {"command": ["set_property", "pause", bool(paused)]}
        s.sendall((json.dumps(payload) + "\n").encode())
        s.close()
        _last[monitor] = paused
    except Exception:
        _last.pop(monitor, None)    # soket kaybolduysa yeniden dene


def recompute():
    monitors = hypr("monitors")
    workspaces = hypr("workspaces")
    if monitors is None or workspaces is None:
        return

    # workspace id -> pencere sayısı
    wcount = {w["id"]: w.get("windows", 0) for w in workspaces}

    for m in monitors:
        name = m.get("name")
        ws = (m.get("activeWorkspace") or {}).get("id")
        if name is None or ws is None:
            continue
        # Ekran kapalıysa da duraklat.
        hidden = m.get("dpmsStatus") is False
        # Aktif workspace'te en az bir pencere varsa duvar kağıdı görünmüyordur.
        covered = wcount.get(ws, 0) > 0
        mpv_set_pause(name, covered or hidden)


def main():
    if not HIS:
        print("HYPRLAND_INSTANCE_SIGNATURE yok", file=sys.stderr)
        return 1

    sock_path = os.path.join(RUNTIME, "hypr", HIS, ".socket2.sock")

    while True:
        try:
            s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            s.connect(sock_path)
        except Exception:
            time.sleep(3)           # Hyprland henüz hazır değil
            continue

        recompute()                 # bağlanır bağlanmaz mevcut duruma getir
        buf = b""
        try:
            while True:
                data = s.recv(4096)
                if not data:
                    break
                buf += data
                while b"\n" in buf:
                    line, buf = buf.split(b"\n", 1)
                    text = line.decode("utf-8", "replace")
                    if any(text.startswith(e) for e in RELEVANT):
                        recompute()
        except Exception:
            pass
        finally:
            try:
                s.close()
            except Exception:
                pass
        _last.clear()
        time.sleep(2)               # bağlantı koptu, yeniden dene


if __name__ == "__main__":
    sys.exit(main())
