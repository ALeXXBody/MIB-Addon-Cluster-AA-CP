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

sed -i '/^GAL_SECONDARY_HIRESEN=/d' "$CONF"
case "$1" in
    on)  echo "GAL_SECONDARY_HIRESEN=1" >> "$CONF"
         echo "Hi-res trial: ON. The next gal start (reboot / phone reconnect)"
         echo "declares the 1280x720 cluster stream beside 800x480; the phone picks."
         echo "If the map goes dark or stays stock, press Hi-res OFF (this same menu)"
         echo "and reboot - the trial key is inert by itself."
         ;;
    off) echo "Hi-res trial: OFF (key removed; the shipped look is restored at the next gal start)."
         ;;
esac
sync
exit 0
