#!/bin/sh
# remote_trace.sh - the STEERING WHEEL diagnostic switch.
#   on   log every outbound InputReport (event=remote.tap) + the parsed
#        gesture (event=remote.trace), LIVE, no restart (v0.7.5 taps the
#        unit's send path: input is car -> phone).
#   off  quiet again.
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

WANT=$([ "$1" = on ] && echo 1 || echo 0)
live_write "$GAL_RUNTIME_DIR/gal_remote_trace" "$WANT" || exit 1

PERSISTED=0
conf_persist set "GAL_REMOTE_TRACE=$WANT" && {
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
}

echo "Wheel trace: $1 (LIVE)."
if [ "$WANT" = 1 ]; then
    echo "Press the wheel now (short OK / long OK / rotary both ways), then"
    echo "10/11. Save logs. The diag shows event=remote.tap for every"
    echo "outbound input report (with its channel) and event=remote.trace"
    echo "for the parsed code/action/delta."
else
    echo "Trace off - the hook stops logging gestures."
fi
[ "$PERSISTED" = 0 ] && echo "NOT persisted: still LIVE until the next gal start."
exit 0
