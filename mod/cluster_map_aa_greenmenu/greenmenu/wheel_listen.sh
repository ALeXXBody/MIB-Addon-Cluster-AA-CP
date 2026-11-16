#!/bin/sh
# wheel_listen.sh - start/stop the steering-wheel listener for the cluster map.
#
# The wheel never reaches Android Auto on this unit (7 live sessions, zero
# outbound InputReport anywhere): wheel up/down shows the MIB map's own zoom
# signs over the AA picture, i.e. the keys are consumed by native MIB. So
# this listener reads them where the HMI itself logs them - the DSI tracer
# stream (car-proven on the same Harman HMI family) - and writes the same
# files the hook's own gestures write:
#   rotary notch -> /tmp/stream-player.zoom (+-0.13, clamped 1.0..1.35)
#   short OK     -> cycle the card-clear preset (/tmp/gal_uiconfig)
#   long OK      -> toggle the turn-info strip (/tmp/stream-player.navstrip)
# View / VC-menu keys are LOGGED ONLY (the cluster's gauge control stays).
#
#     wheel_listen.sh on|off
# Exit 0: switched. 3: nothing to change or not supported. Else failed.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

case "$1" in
    on|off) WANT="$1" ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

RT="${GAL_RUNTIME_DIR:-/tmp}"
FLAG="$RT/gal_wheellisten"
PIDF="$RT/gal_wheellisten.pid"

# The staged copy (enable_hook.sh puts it next to the player and chmods
# it executable; FAT cards carry no exec bit, so the card copy is never
# run from). The APP_MOUNT spelling already walks every app view the
# console can see.
BIN="$APP_MOUNT/eso/lib/gal_dualscreen/wheel_listen"
if [ ! -x "$BIN" ]; then BIN=""; fi

_pid_alive() {
    [ -r "$PIDF" ] || return 1
    _p=`cat "$PIDF" 2>/dev/null` || _p=""
    case "$_p" in ''|*[!0-9]*) return 1 ;; esac
    kill -0 "$_p" 2>/dev/null
}

if [ "$WANT" = "on" ]; then
    if [ -z "$BIN" ]; then
        echo "Wheel listen needs the staged listener: install the map first"
        echo "(enable_hook stages wheel_listen next to the player)."
        echo "Nothing changed."
        exit 3
    fi
    live_write "$FLAG" "1" || exit 1
    if _pid_alive; then
        echo "Wheel listen: ON (already running, pid `cat "$PIDF"`)."
    else
        "$BIN" </dev/null >"$RT/gal_wheel.out" 2>&1 &
        echo "$!" > "$PIDF" 2>/dev/null || true
        echo "Wheel listen: ON (listener started, pid `cat "$PIDF" 2>/dev/null`)."
    fi
    echo "  rotary      -> zoom the cluster map +-"
    echo "  short OK    -> cycle the card-clear preset"
    echo "  long OK     -> toggle the turn-info strip"
    echo "  needs the HMI tracer: run Wheel tracer ON, then reboot."
    if ! conf_persist set "GAL_WHEEL_LISTEN=1"; then
        echo "(persistence refused: $(echo "$APP_LADDER_ERRORS" | tail -1))"
        echo "LIVE arm holds until the next gal start."
    else
        echo "Persisted: survives reboots."
    fi
    exit 0
fi

# off: stop the listener, drop the flag. The tracer scoping stays (it is
# owned by the Wheel tracer switch, which restores the .orig on off).
if _pid_alive; then
    _p=`cat "$PIDF" 2>/dev/null` || _p="?"
    kill "$_p" 2>/dev/null || true
    echo "Wheel listen: OFF (listener pid $_p stopped)."
else
    echo "Wheel listen: OFF (was not running). Nothing changed."
fi
unset _p
rm -f "$PIDF" 2>/dev/null || true
live_write "$FLAG" "0" || exit 1
if ! conf_persist set "GAL_WHEEL_LISTEN=0"; then
    echo "(persistence refused: $(echo "$APP_LADDER_ERRORS" | tail -1))"
fi
exit 0
