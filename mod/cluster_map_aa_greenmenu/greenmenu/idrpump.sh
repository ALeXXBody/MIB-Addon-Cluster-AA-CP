#!/bin/sh
# idrpump.sh - map text sharpening between the phone's key frames.
#   idrpump.sh SECONDS (>=10; start with 25) | off
# LIVE: the focus controller polls /tmp/gal_idr_pump every second.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi
CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
case "$1" in
    [0-9]*)  NUM=$1 ;;
    off)     NUM= ;;
    *) echo "usage: $0 SECONDS|off" >&2; exit 2 ;;
esac
if [ -n "$NUM" ]; then
    case "$NUM" in *[!0-9]*) echo "usage: $0 SECONDS|off" >&2; exit 2 ;; esac
    [ "$NUM" -lt 10 ] && NUM=10
    [ "$NUM" -gt 300 ] && NUM=300
fi

# The hook reads /tmp/gal_idr_pump as a BARE INTEGER (fscanf "%ld"),
# seconds or 0; "GAL_IDR_PUMP=25" was unreadable and the pump never
# started (v0.7.4 car round). The persisted key keeps KEY=VALUE.
live_write "$GAL_RUNTIME_DIR/gal_idr_pump" "${NUM:-0}" || exit 1

PERSISTED=0
conf_persist set "GAL_IDR_PUMP=${NUM:-0}" && {
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
}

case "$NUM" in
    '') echo "Sharpness pump: OFF (LIVE - stops pulsing within a second)." ;;
    *)  echo "Sharpness pump: every $NUM s (LIVE - pulsing starts within a second;"
        echo "the brief blink is the price of fresh key frames)." ;;
esac
[ "$PERSISTED" = 0 ] && echo "NOT persisted: still LIVE until the next gal start."
exit 0
