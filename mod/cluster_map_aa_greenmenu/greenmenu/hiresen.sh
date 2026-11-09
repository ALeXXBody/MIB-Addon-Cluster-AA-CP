#!/bin/sh
# hiresen.sh - trial the phone-port sharpness ceiling: ask the phone for
# the cluster stream coded at 1280x720 (AA codec enum 2 requires the
# v0.6.0 hook; the trial key is harmless for an older hook - nothing
# reads it).
#   hiresen.sh on   next gal start declares 1280x720 beside 800x480
#   hiresen.sh off  historical identity restored (remove the key)
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
case "$1" in
    on)  : ;;
    off) : ;;
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

# v0.7.1: the runtime file /tmp/gal_hires is read by the hook when it
# builds the next phone session - so the choice lands at the NEXT PHONE
# SESSION (unplug/replug the USB or cycle phone AA), not at a reboot.
echo "GAL_SECONDARY_HIRESEN=$([ "$1" = on ] && echo 1 || echo 0)" > /tmp/gal_hires
sed -i '/^GAL_SECONDARY_HIRESEN=/d' "$CONF"
case "$1" in
    on)  echo "GAL_SECONDARY_HIRESEN=1" >> "$CONF"
         echo "Hi-res trial: ON (LIVE ARMED) - declares the 1280x720 stream"
         echo "beside 800x480 at your NEXT PHONE SESSION (re-plug the USB or"
         echo "cycle the phone's AA). The phone picks a resolution at that"
         echo "point. If the map goes dark, press Hi-res OFF then reconnect."
         ;;
    off) echo "Hi-res trial: OFF (LIVE ARMED) - back to the shipped look at the next phone session."
         ;;
esac
sync
exit 0
