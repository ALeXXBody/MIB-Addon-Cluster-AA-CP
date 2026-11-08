#!/bin/sh
#
# navstrip.sh — "Turn info in the info bar" (the strip the Addon's GEM
# calls experimental). Turns the strip that the fork player draws at the
# bottom of the cluster map on or off, in the car, without an install:
#
#   navstrip.sh on | off
#
#   on   the player's live row shows what the hook decoded from the AA
#        navigation channel: the road name | ETA | distance of the next
#        turn, as long as the phone sends them (Android Auto 1.6+).
#   off  the strip goes away; the map covers the whole window again.
#
# How it lands: this writes BOTH halves. (1) the player's own live control
# file /tmp/stream-player.navstrip ("1"/"0": the running player picks it up
# within a second). (2) the settings line GAL_NAV_INFO_STRIP=1, so a
# freshly started player also has the strip on. The player's frame loop
# polls both at most once a second; the hook writes the info file
# (/tmp/gal_nav_info) when its own GAL_NAV_INFO_FILE=1 is set (this switch
# sets that too via the settings file).
#
# The installer writes the two settings switches (GAL_NAV_INFO_STRIP and
# GAL_NAV_INFO_FILE) with their stock "0"; so this switch can turn them
# both off and back on without a re-install.
#
# Exit 0 switched; 3 nothing to change.
#
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
    on)  WANT=1  ;;
    off) WANT=0  ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi

mount -uw "$APP_MOUNT" 2>/dev/null || { echo "Cannot remount $APP_MOUNT read-write. Nothing changed."; exit 1; }

strip_now=`sed -n 's/^GAL_NAV_INFO_STRIP=//p' "$CONF" | tail -1`
file_now=`sed -n 's/^GAL_NAV_INFO_FILE=//p' "$CONF" | tail -1`
if [ "$strip_now" = "$WANT" ] && [ "$file_now" = "$WANT" ]; then
    echo "Turn info strip is already $([ "$WANT" = 1 ] && echo ON || echo OFF). Nothing changed."
    exit 3
fi

if [ "$WANT" = 1 ]; then
    sed -i '/^GAL_NAV_INFO_STRIP=/d' "$CONF"
    echo "GAL_NAV_INFO_STRIP=1" >> "$CONF"
    sed -i '/^GAL_NAV_INFO_FILE=/d' "$CONF"
    echo "GAL_NAV_INFO_FILE=1" >> "$CONF"
    sync
    echo 1 > /tmp/stream-player.navstrip 2>/dev/null || true
    echo "Turn info strip: ON. The strip reads the hook's live file; if no"
    echo "route is active right now it will appear as soon as the map"
    echo "re-routes (the hook's decoded road name | ETA | distance)."
else
    sed -i '/^GAL_NAV_INFO_STRIP=/d' "$CONF"
    echo "GAL_NAV_INFO_STRIP=0" >> "$CONF"
    sed -i '/^GAL_NAV_INFO_FILE=/d' "$CONF"
    echo "GAL_NAV_INFO_FILE=0" >> "$CONF"
    sync
    echo 0 > /tmp/stream-player.navstrip 2>/dev/null || true
    echo "Turn info strip: OFF."
fi
