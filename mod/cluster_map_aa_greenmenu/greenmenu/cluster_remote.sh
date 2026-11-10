#!/bin/sh

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
    on)  WANT=1 ;;
    off) WANT=0 ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac
# v0.7.2: LIVE - the hook reads /tmp/gal_remote at each wheel event, so
# the binding turns on/off without a restart (no reboot needed).
echo "$WANT" > /tmp/gal_remote

if [ ! -r "$CONF_READ" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
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

sed -i '/^GAL_CLUSTER_REMOTE=/d' "$CONF"
echo "GAL_CLUSTER_REMOTE=$WANT" >> "$CONF"

sync
echo "Cluster remote (OK press on the cluster): $([ "$WANT" = 1 ] && echo ON || echo OFF) (LIVE)"
echo "  short OK press  -> cycle the card-clear preset"
echo "  long OK press   -> toggle the turn-info strip"
echo "  rotary          -> zoom +/-"
echo "LIVE: bound at the next wheel gesture; a reboot only validates the persisted key."
