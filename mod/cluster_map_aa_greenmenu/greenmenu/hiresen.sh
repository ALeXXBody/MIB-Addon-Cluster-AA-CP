#!/bin/sh
# hiresen.sh - trial the phone-port sharpness ceiling: ask the phone for
# the cluster stream coded at 1280x720 (AA codec enum 2, v0.6.0+ hook).
#   hiresen.sh on|off   LIVE for the NEXT phone session (no reboot)
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
# The hook reads /tmp/gal_hires as a BARE INTEGER (fscanf "%d"): writing
# "GAL_SECONDARY_HIRESEN=1" here made the file unreadable and the switch
# a no-op (v0.7.4 car round). The persisted key keeps its KEY=VALUE form;
# the runtime file is the value only.
live_write "$GAL_RUNTIME_DIR/gal_hires" "$WANT" || exit 1

PERSISTED=0
conf_persist set "GAL_SECONDARY_HIRESEN=$WANT" && {
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
}

if [ "$WANT" = 1 ]; then
    echo "Hi-res trial: ON (LIVE ARMED) - the next phone session declares 1280x720"
    echo "beside 800x480. Re-plug the USB (or cycle the phone's AA) to apply."
    echo "If the map goes dark, press Hi-res OFF and reconnect."
else
    echo "Hi-res trial: OFF (LIVE ARMED) - back to the shipped 800x480 at the next phone session."
fi
[ "$PERSISTED" = 0 ] && echo "NOT persisted: still LIVE until the next gal start."
exit 0
