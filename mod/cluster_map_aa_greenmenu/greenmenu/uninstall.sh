#!/bin/sh
HERE=`dirname "$0"`
. "$HERE/common.sh"
# The view/remount ladder lives in scripts/. common.sh does not source it,
# and a GEM press MUST open a writable app window of its own: disable_hook
# (the previous step) deliberately remounts the app partition read-only
# again before this process starts. Without this, the engdefs probe below
# always fails on the owner's MHI2 (local spelling refused, root refused)
# and the menu screen survives every uninstall.
if [ -r "$PKG/scripts/lib_app_mount.sh" ]; then
    . "$PKG/scripts/lib_app_mount.sh"
elif [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
elif [ -r "$HERE/lib_app_mount.sh" ]; then
    . "$HERE/lib_app_mount.sh"
fi
# View-aware unit paths: the same file can live under several spellings of
# the app/system partitions depending on which node the console runs on
# (MHI2 prints /net/mmx.mibhigh.net/... — the FQDN QNET view). Pick the
# spelling that EXISTS for reads, and remount/probe the one that works for
# writes; see lib_app_mount.sh for the ladder this mirrors.
CONFIG=""
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    [ -r "$_v/etc/eso/production/smartphone_integrator.json" ] && { CONFIG=$_v/etc/eso/production/smartphone_integrator.json; break; }
done
[ -n "$CONFIG" ] || CONFIG=/mnt/system/etc/eso/production/smartphone_integrator.json
HOOK_DIR=""
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v/eso/lib/gal_dualscreen" ] && { HOOK_DIR=$_v; break; }
done
[ -n "$HOOK_DIR" ] || HOOK_DIR=/mnt/app
RC=0
if grep -q 'libgal_hook.so' "$CONFIG" 2>/dev/null || [ -d $HOOK_DIR/eso/lib/gal_dualscreen ]; then
    sh "$PKG/disable_hook.sh"
    RC=$?
else
    echo "The cluster map is not installed."
fi
# The wheel listener outlives the staged dir (it runs from /tmp state):
# stop it, best-effort, so no orphan keeps writing zoom files for a
# player that is gone. Never fatal to the uninstall verdict.
if [ -r /tmp/gal_wheellisten.pid ]; then
    kill "`cat /tmp/gal_wheellisten.pid 2>/dev/null`" 2>/dev/null || true
    rm -f /tmp/gal_wheellisten.pid 2>/dev/null || true
fi
slay wheel_listen 2>/dev/null || true
rm -f /tmp/gal_wheellisten 2>/dev/null || true
# The turn-by-turn arrows, when this package installed them instead of the map.
if [ -f $HOOK_DIR/eso/hmi/lsd/.aacluster_tbt_added ]; then
    sh "$PKG/turn_by_turn.sh" uninstall || RC=1
fi
# The menu screen the update copied. Its files stay on the card, and a
# COLLECT.txt update brings it back for Save logs. Removal needs a WRITE,
# so open a window HERE: the disable_hook process above remounted the app
# read-only before this script got control. Probe the real target
# (engdefs), not just the preload folder, which is gone on a stock-ish unit.
APP_OK=0
if app_mount_rw || app_mount_rw_at "eso/hmi/engdefs"; then
    APP_OK=1
    echo "$APP_LADDER_OK"
    trap 'app_mount_finish' 0 1 2 15
else
    echo "Cannot open a writable app view - the menu screen cannot be removed." >&2
    echo "$APP_LADDER_ERRORS" >&2
    RC=1
fi
ENGDEFS_REMOVED=0
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
    [ "$APP_OK" = 1 ] || break
    _edefs="$_v/eso/hmi/engdefs"
    [ -f "$_edefs/cluster-map.esd" ] || continue
    # write-probe (this unit REFUSES mkdir; file writes beside it work)
    ( : > "$_edefs/.clustermap_probe" ) 2>/dev/null || continue
    rm -f "$_edefs/.clustermap_probe" 2>/dev/null
    if rm -f "$_edefs/cluster-map.esd"; then
        echo "Removed the menu screen (view: $_v)."
        ENGDEFS_REMOVED=1
    fi
    break
done
if [ "$ENGDEFS_REMOVED" = 0 ] && [ $RC -eq 0 ]; then
    echo "Menu screen not found under any app view (nothing to remove)."
fi
echo
if [ $RC -eq 0 ]; then
    echo "CLUSTERMAP_UNINSTALL_OK"
    echo "Hold the power button for 10 seconds to reboot the unit."
else
    echo "CLUSTERMAP_UNINSTALL_FAILED (code $RC). Read the messages above."
fi
# The old `exit 0` made a failed restore print FAILED and then tell the GEM
# verdict "DONE". Propagate the real result: the run log already names the
# failure, and run_verdict must not call a broken uninstall a success.
exit "$RC"
