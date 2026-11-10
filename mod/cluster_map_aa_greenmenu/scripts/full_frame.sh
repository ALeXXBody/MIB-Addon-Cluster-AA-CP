#!/bin/sh
# The green menu's sharper-map switch: CLUSTERMAP_FULL_FRAME on or off in the
# unit's own copy of the settings, so it can be tried in the car without
# editing the card and installing again. Changes only the window lines of
# that copy (lib_cluster_frame.sh); takes effect at the next reboot: gal
# reads the settings once at its start and hands the same frame values to
# every player it starts until then. An install from the card writes the
# card's setting again.
# From AMDFX60's fork (GPL-3.0).
#
#   full_frame.sh on|off
# Exit 0: switched, reboot. 3: nothing to change. Anything else: failed.
HERE=`dirname "$0"`
. "$HERE/lib_app_mount.sh"
. "$HERE/lib_cluster_frame.sh"
CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"

case "$1" in
    on)  WANT=1 ;;
    off) WANT=0 ;;
    *)   echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF_READ" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi
WINDOW=`sed -n 's/^[ 	]*GAL_PLAYER_WINDOW[ 	]*=[ 	]*\([0-9][0-9]*x[0-9][0-9]*\)[ 	]*$/\1/p' "$CONF_READ" | tail -1`
MAP_W=`echo "$WINDOW" | sed -n 's/^\([0-9]*\)x[0-9]*$/\1/p'`
MAP_H=`echo "$WINDOW" | sed -n 's/^[0-9]*x\([0-9]*\)$/\1/p'`
if [ -z "$MAP_W" ] || [ -z "$MAP_H" ] || [ "$MAP_W" -lt 320 ] || [ "$MAP_W" -gt 1920 ] ||
   [ "$MAP_H" -lt 160 ] || [ "$MAP_H" -gt 1080 ]; then
    echo "The settings copy names no cluster map window. Install again from the"
    echo "card (with the cockpit in map view), then use this switch."
    exit 1
fi
# Written only by an installer that has the full-frame hook and player; an
# older install would take the settings and draw a squeezed map.
if ! grep -q "^$FRAME_CONF_MARK$" "$CONF_READ" 2>/dev/null; then
    echo "The cluster map on the unit was installed by an older release, which"
    echo "cannot draw the sharper map. Choose \"Install cluster map\" from this"
    echo "card first, then use this switch. Nothing changed."
    exit 1
fi
if [ "$WANT" = 1 ] && ! frame_full_ok $MAP_W $MAP_H; then
    echo "The cluster map window is ${MAP_W}x${MAP_H}, not wider than Android Auto's"
    echo "5:3 frame: the map already uses every line, so there is nothing to switch."
    exit 3
fi

NOW=`sed -n 's/^CLUSTERMAP_FULL_FRAME=\([01]\)[ 	]*$/\1/p' "$CONF_READ" | tail -1`
[ "$NOW" = 1 ] || NOW=0
if [ "$NOW" = "$WANT" ]; then
    echo "Sharper map is already $1. Nothing changed."
    exit 3
fi

# Shared LADDER (the switch-audit fix): the single local spelling is not
# enough on cars whose console only remounts app via another view form
# (owner diag: "Cannot remount /mnt/app" killed EVERY switch silently).
# Write through the alias that actually took the remount.
if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"
APP_WRITABLE=1
trap app_mount_finish 0 1 2 15
if ! frame_write_conf "$CONF" $MAP_W $MAP_H $WANT; then
    echo "Could not write $CONF. Nothing changed."
    exit 1
fi
sync
if [ "$WANT" = 1 ]; then
    echo "Sharper map: ON."
    echo "Android Auto now draws on the whole 800x480 frame, pixel aspect"
    echo "${PIXEL_ASPECT_E4}/10000, stretched to the ${MAP_W}x${MAP_H} window. The hook"
    echo "scales DPI and insets by the same ratio, so the map should keep its"
    echo "scale and the turn card its place. Compare with OFF after a reboot."
else
    echo "Sharper map: OFF."
    echo "Back to ${MARGIN_W}x${MARGIN_H} margins."
fi
echo "Hold the power button for 10 seconds to reboot the unit."
exit 0
