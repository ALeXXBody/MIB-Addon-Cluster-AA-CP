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
CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"

case "$1" in
    on)  WANT="phone" ;;
    off) WANT="auto" ;;
    *)   echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF_READ" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi
# The arbiter is a fork-source feature: it needs a player that knows
# GAL_KEEP_MAP. The upstream v1.1.0 Tiguan release binaries do not have it, so
# with those the switch must refuse instead of writing a line the player will
# ignore. (A fork-built payload passes this check silently.)
PLAYER="$APP_MOUNT/navigation/stream-player"
if [ ! -r "$PLAYER" ] || ! grep -q "GAL_KEEP_MAP" "$PLAYER" 2>/dev/null; then
    echo "This switch does nothing on this unit: the installed stream-player has"
    echo "no cockpit source arbiter (upstream release player). The installed map"
    echo "behaves as upstream designed; nothing changed."
    exit 3
fi
# POSIX-safe rewrite through a new file and rename, like lib_cluster_frame.sh.
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

if grep -q "^GAL_KEEP_MAP=" "$CONF_READ"; then
    sed "s/^GAL_KEEP_MAP=.*/GAL_KEEP_MAP=$WANT/" "$CONF" > "$CONF.new" 2>/dev/null &&
    mv "$CONF.new" "$CONF" 2>/dev/null || {
        echo "Could not rewrite GAL_KEEP_MAP in $CONF. Nothing changed."; rm -f "$CONF.new"; exit 1; }
else
    echo "GAL_KEEP_MAP=$WANT" >> "$CONF" || { echo "Could not add GAL_KEEP_MAP to $CONF. Nothing changed."; exit 1; }
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
