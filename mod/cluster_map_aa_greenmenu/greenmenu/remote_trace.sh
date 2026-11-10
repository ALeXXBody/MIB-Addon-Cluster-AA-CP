#!/bin/sh
# remote_trace.sh - the STEERING WHEEL diagnostic switch.
#   remote_trace.sh on   every wheel gesture reaching the hook is logged
#                        at INFO level (code/action/rotary delta), and
#                        the trace is LIVE (read at each incoming event,
#                        no restart). Once armed, press the wheel, then
#                        Save logs: the diag shows exactly what arrived.
#   remote_trace.sh off
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
case "$1" in
    on|off) : ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"

# the trace is LIVE: /tmp/gal_remote_trace is read by the hook at each
# incoming input event
echo "$([ "$1" = on ] && echo 1 || echo 0)" > /tmp/gal_remote_trace
echo "Wheel trace: $1 (LIVE - read at each incoming gesture, no restart)."
echo "Run: Cluster menu entries on the wheel, then 10/11. Save logs - the"
echo "diag will show every gesture's own code/action exactly as it arrived."
