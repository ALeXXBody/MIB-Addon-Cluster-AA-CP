#!/bin/sh
# idrpump.sh - map text sharpening between the phone's own ~60 s key
# frames. GAL_IDR_PUMP=SECONDS makes the hook bounce the cluster's video
# focus briefly every N seconds (player stays up, mode 2 / back) so the
# phone keeps sending fresh IDR key frames. Needs the v0.6.1 hook; the
# key is inert on an older one. OFF by default.
#   idrpump.sh SECONDS   (>= 10; start with 25)
#   idrpump.sh off       historical behaviour (no key)
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

if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"

sed -i '/^GAL_IDR_PUMP=/d' "$CONF"
case "$NUM" in
    '') echo "Sharpness pump: OFF (key removed; lands at the next gal start)." ;;
    *)  echo "GAL_IDR_PUMP=$NUM" >> "$CONF"
        echo "Sharpness pump: every $NUM s the hook keeps the cluster's"
        echo "key-recess closest: mode 2 / brief / re-grant (player stays up;"
        echo "the brief blink of re-key is the price). Lands at the next gal"
        echo "start (reboot or reconnect the phone)."
        ;;
esac
sync
exit 0
