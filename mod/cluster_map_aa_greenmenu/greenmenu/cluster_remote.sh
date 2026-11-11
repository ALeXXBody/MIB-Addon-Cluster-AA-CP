#!/bin/sh
# cluster_remote.sh - the steering wheel remote for the cluster map.
#
# v0.7.5: the LIVE arm comes FIRST and does not depend on any remount.
# The v0.7.5 hook taps the unit's OUTBOUND InputReport path and reads
# /tmp/gal_remote at every gesture, so this file is the arm: once it
# reads 1, the very next wheel press is routed. Persistence (unit copy
# or card root) only matters for the next gal start.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi
CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"

case "$1" in
    on)  WANT=1 ;;
    off) WANT=0 ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

# 1) the LIVE arm - the only write the hook needs right now
live_write "$GAL_RUNTIME_DIR/gal_remote" "$WANT" || exit 1

# 2) persist for the next gal start: the file the hook actually loads
# (card root when one exists, else the unit copy) and remount app ro again.
PERSISTED=0
if conf_persist set "GAL_CLUSTER_REMOTE=$WANT"; then
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
else
    echo "(persistence refused: $(echo "$APP_LADDER_ERRORS" | tail -1))"
fi

if [ "$WANT" = 1 ]; then
    echo "Cluster remote: ON (LIVE) - the wheel is armed for the NEXT press."
    echo "  short OK press  -> cycle the card-clear preset"
    echo "  long OK press   -> toggle the turn-info strip"
    echo "  rotary          -> zoom +/-"
else
    echo "Cluster remote: OFF (LIVE)."
fi
case "$PERSISTED" in
    1) echo "Persisted in the unit's copy: survives reboots." ;;
    2) echo "Persisted on the card root: survives reboots (read at gal start)." ;;
    *) echo "NOT persisted (both write paths refused): the LIVE arm holds until the next gal start." ;;
esac
exit 0
