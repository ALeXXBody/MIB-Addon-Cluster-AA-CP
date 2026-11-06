#!/bin/sh

HERE=`dirname "$0"`
. "$HERE/lib_app_mount.sh"
CONF="$PRELOAD_WRITE_DIR/gal_dualscreen.conf"

case "$1" in
    on)  WANT=1 ;;
    off) WANT=0 ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi

mount -uw "$APP_MOUNT" 2>/dev/null || { echo "Cannot remount $APP_MOUNT read-write. Nothing changed."; exit 1; }

sed -i '/^GAL_CLUSTER_REMOTE=/d' "$CONF"
echo "GAL_CLUSTER_REMOTE=$WANT" >> "$CONF"

sync
echo "Cluster remote (OK press on the cluster): $([ "$WANT" = 1 ] && echo ON || echo OFF)"
echo "  short OK press  -> cycle the card-clear preset"
echo "  long OK press   -> toggle the turn-info strip"
echo "  rotary          -> zoom +/-"
echo "Stage: the switch lands at the NEXT gal start (phone reconnect / reboot)."
