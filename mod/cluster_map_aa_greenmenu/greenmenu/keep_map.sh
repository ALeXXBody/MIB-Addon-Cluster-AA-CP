#!/bin/sh
# Fork addition: the green menu's keep-map arbiter switch. Sets
# GAL_KEEP_MAP=phone in the unit's own copy of the settings, so the player
# re-asserts the cluster map while the phone streams (upstream switch-back
# race #19/#43). Takes effect at the next session start (stream-player reads
# its settings once at start). An install from the card writes the card's
# setting again. Nothing to do here on a factory map: the arbiter also stops
# automatically after GAL_KEEP_MAX re-asserts per session.
#
#   keep_map.sh on|off
# Exit 0: switched (takes effect on the next connect/reboot). 3: nothing to change.
HERE=`dirname "$0"`
. "$HERE/lib_app_mount.sh"
CONF="$PRELOAD_WRITE_DIR/gal_dualscreen.conf"

case "$1" in
    on)  WANT="phone" ;;
    off) WANT="auto" ;;
    *)   echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi
# POSIX-safe rewrite through a new file and rename, like lib_cluster_frame.sh.
mount -uw "$APP_MOUNT" 2>/dev/null || { echo "Cannot remount $APP_MOUNT read-write. Nothing changed."; exit 1; }
APP_WRITABLE=1
trap app_mount_finish 0 1 2 15

if grep -q "^GAL_KEEP_MAP=" "$CONF"; then
    sed "s/^GAL_KEEP_MAP=.*/GAL_KEEP_MAP=$WANT/" "$CONF" > "$CONF.new" 2>/dev/null &&
    mv "$CONF.new" "$CONF" 2>/dev/null || {
        echo "Could not rewrite GAL_KEEP_MAP in $CONF. Nothing changed."; rm -f "$CONF.new"; exit 1; }
else
    printf 'GAL_KEEP_MAP=%s\n' "$WANT" >> "$CONF" || { echo "Could not add GAL_KEEP_MAP to $CONF. Nothing changed."; exit 1; }
fi
sync
if [ "$WANT" = "phone" ]; then
    echo "Keep map: ON (the player re-asserts its map while the phone streams)."
    echo "Connect the phone and watch a route start: if the car's map comes back, the"
    echo "arbiter puts the phone's map straight back, up to 30 times per session."
    echo "Set GAL_KEEP_INTERVAL_S / GAL_KEEP_MAX on the card to change that."
else
    echo "Keep map: OFF. Upstream behaviour: one switch per connect."
fi
exit 0
