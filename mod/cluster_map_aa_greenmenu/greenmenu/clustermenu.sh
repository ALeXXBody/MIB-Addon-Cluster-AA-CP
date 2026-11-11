#!/bin/sh
# clustermenu.sh - the in-cluster menu switch (v0.7.0).
#   clustermenu.sh on|off
# LIVE: the hook checks /tmp/gal_cluster_menu at every wheel gesture.
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
# The hook reads /tmp/gal_cluster_menu as a SINGLE CHARACTER '0'/'1'
# (len==1 check); "GAL_CLUSTER_MENU=1" was ignored, so the switch
# reported success and changed nothing (v0.7.4 car round).
live_write "$GAL_RUNTIME_DIR/gal_cluster_menu" "$WANT" || exit 1

PERSISTED=0
conf_persist set "GAL_CLUSTER_MENU=$WANT" && {
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
}

if [ "$WANT" = 1 ]; then
    echo "Cluster menu: ON (LIVE) - SHORT OK opens the overlay on the cluster,"
    echo "rotary navigates, OK applies; LONG OK stays the strip toggle."
else
    echo "Cluster menu: OFF (LIVE) - short OK cycles the ETA card, rotary zooms."
fi
[ "$PERSISTED" = 0 ] && echo "NOT persisted: still LIVE until the next gal start."
exit 0
