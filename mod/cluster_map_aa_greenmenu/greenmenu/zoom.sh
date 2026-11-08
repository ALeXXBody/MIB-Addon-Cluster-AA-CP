#!/bin/sh
# Fork feature: the green menu's player zoom switch. The player crops the
# phone's picture around its centre and stretches it into the cluster window
# (guh_player_zoom: GAL_PLAYER_ZOOM_E4, runtime file /tmp/stream-player.zoom).
# The runtime file takes effect right away, without a session restart; the
# settings copy lasts across reboots. An install from the card writes the
# card's setting again.
#
#     zoom.sh off|1.0|1.15|1.35     ("off" and "1.0" are the same: 10000)
# Exit 0: switched. 3: nothing to change or not supported. Anything else: failed.
HERE=`dirname "$0"`
# the shared lib lives in the payload's scripts/ folder (round-13 class
# bug: a missing source line ABORTS the shell - guard it explicitly)
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
elif [ -r "$HERE/lib_app_mount.sh" ]; then
    . "$HERE/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi
CONF="$PRELOAD_WRITE_DIR/gal_dualscreen.conf"

case "$1" in
    off|1.0)  WANT=10000; FACT=1.0 ;;
    1.15)     WANT=11500; FACT=1.15 ;;
    1.35)     WANT=13500; FACT=1.35 ;;
    *)   echo "usage: $0 off|1.0|1.15|1.35" >&2; exit 2 ;;
esac

if [ ! -r "$CONF" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi
# Zoom is a fork-source feature: it needs a player that knows it. The upstream
# v1.1.0 Tiguan release player does not have it, so with that the switch must
# refuse instead of writing a line the player ignores.
PLAYER="$APP_MOUNT/navigation/stream-player"
if [ ! -r "$PLAYER" ] || ! grep -q "GAL_PLAYER_ZOOM_E4" "$PLAYER" 2>/dev/null; then
    echo "These zoom switches cannot work on this unit: the installed"
    echo "stream-player has no zoom code (upstream release player). Nothing"
    echo "changed; the map keeps its 1.0 view."
    exit 3
fi
# POSIX-safe rewrite through a new file and rename, like lib_cluster_frame.sh.
mount -uw "$APP_MOUNT" 2>/dev/null || { echo "Cannot remount $APP_MOUNT read-write. Nothing changed."; exit 1; }
APP_WRITABLE=1
trap app_mount_finish 0 1 2 15

if grep -q "^GAL_PLAYER_ZOOM_E4=" "$CONF"; then
    sed "s/^GAL_PLAYER_ZOOM_E4=.*/GAL_PLAYER_ZOOM_E4=$WANT/" "$CONF" > "$CONF.new" 2>/dev/null &&
    mv "$CONF.new" "$CONF" 2>/dev/null || {
        echo "Could not rewrite GAL_PLAYER_ZOOM_E4 in $CONF. Nothing changed."; rm -f "$CONF.new"; exit 1; }
else
    echo "GAL_PLAYER_ZOOM_E4=$WANT" >> "$CONF" || { echo "Could not add GAL_PLAYER_ZOOM_E4 to $CONF. Nothing changed."; exit 1; }
fi
sync
# Live change for the running session (the player polls this small file):
# one float on a line. It only exists for this session; the conf line above
# is what fresh sessions read.
echo "$FACT" > /tmp/stream-player.zoom 2>/dev/null || true
if [ "$WANT" = 10000 ]; then
    echo "Zoom: 1.0 (off). The map draws as the phone sends it, no cropping."
else
    echo "Zoom: $FACT. The player crops the phone's picture around its centre"
    echo "and stretches it into the cluster window."
    echo "The running map applies it within a few seconds; a session that"
    echo "starts after this reads the same value from the settings copy."
fi
exit 0
