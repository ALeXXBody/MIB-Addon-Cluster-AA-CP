#!/bin/sh
. "`dirname "$0"`/common.sh"
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
# The turn-by-turn arrows, when this package installed them instead of the map.
if [ -f $HOOK_DIR/eso/hmi/lsd/.aacluster_tbt_added ]; then
    sh "$PKG/turn_by_turn.sh" uninstall || RC=1
fi
# The menu screen the update copied. Its files stay on the card, and a
# COLLECT.txt update brings it back for Save logs. Removal needs a WRITE,
# so probe writability through the same spelling being used.
ENGDEFS_REMOVED=0
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
    [ -f "$_v/eso/hmi/engdefs/cluster-map.esd" ] || continue
    mount -uw "$_v" 2>/dev/null
    if mkdir "$_v/eso/hmi/.clustermap_probe" 2>/dev/null; then
        rmdir "$_v/eso/hmi/.clustermap_probe" 2>/dev/null
        rm -f $_v/eso/hmi/engdefs/cluster-map.esd && {
            echo "Removed the menu screen (view: $_v)."
            ENGDEFS_REMOVED=1
        }
        mount -ur "$_v" 2>/dev/null
        break
    fi
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
exit 0
