#!/bin/sh
#
# revert_aa_hook.sh — removes exactly what the M.I.B.-Addon-Cluster-AA-CP
# install added to this unit, leaving EVERYTHING else untouched (no
# firmware flash, FEC/coding/M.I.B. customisations preserved).
#
# It is written to run from ANY shell this unit can offer:
#   * the emergency serial console (the GEM-dead rescue channel),
#   * SSH/telnet (if such a daemon was installed before the hang),
#   * M.I.B.'s GEM, once the unit lets you in again
#     (then: Run /mod/custom.sh is not required — run this file directly
#      through M.I.B.'s "Run custom script" on
#      mod/cluster_map_aa_greenmenu/rescue_revert.sh).
#
# No arguments. Idempotent: safe to run twice.
#
# What it reverts (in this order, each step printed):
#   1. engdefs screen file  /eso/hmi/engdefs/cluster-map.esd           [delete]
#      (the GEM parses this at every boot — first suspect of the hang)
#   2. supervisor config     smartphone_integrator.json                [restore]
#      from the untouched unit-side backup our install stored:
#        <system view>/etc/eso/production/
#            smartphone_integrator.json.gal-dualscreen.original
#      or (if that is missing) from the card copy the installer kept:
#        <card>/backups/smartphone_integrator.json.original
#   3. hook files            /eso/lib/gal_dualscreen (dir)             [delete]
#                            /eso/lib/libdmdt_flush.so                 [delete]
#   4. lsd.sh jar line +     NavActiveIgnore.jar                       [delete line]
#      markers               .aacluster_navignore_added,
#                            .aacluster_tbt_added, .aacluster_navignore_added
#
# NOT touched on purpose:
#   * /mnt/app/navigation/stream-player — our player replaced the stock one;
#     it runs only inside AA sessions, cannot affect the GEM, and there is
#     no stock copy to restore. A later clean M.I.B. reinstall brings the
#     stock player back if wanted.

trap '' 2

echo "#------------------------------------------------------------------"
echo "# revert_aa_hook: removing what MIB-Addon-Cluster-AA-CP installed"
echo "#------------------------------------------------------------------"

# ---- view ladder -------------------------------------------------------
# The same views the payload scripts use; the first that resolves wins.
APPV="/mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app"
SYSV="/mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system"

APP=""; for _v in $APPV; do
    [ -d "$_v/eso" ] && { APP="$_v"; break; }
done
SYS=""; for _v in $SYSV; do
    [ -d "$_v/etc/eso/production" ] && { SYS="$_v"; break; }
done
CARD=""; for _v in /fs/sda0 /fs/sdb0 /net/mmx/fs/sda0 /net/mmx.mibhigh.net/fs/sda0 /net/mmx/fs/sdb0; do
    [ -d "$_v/mod/cluster_map_aa_greenmenu" ] && { CARD="$_v"; break; }
done
echo "views: app='$APP' system='$SYS' card='$CARD'"

if [ -n "$APP" ]; then mount -uw "$APP" 2>/dev/null; fi
if [ -n "$SYS" ]; then mount -uw "$SYS" 2>/dev/null; fi

# ---- 1. engdefs screen file --------------------------------------------
E1="$APP/eso/hmi/engdefs/cluster-map.esd"
if [ -f "$E1" ]; then
    rm -f "$E1" && echo "1. removed GEM screen: $E1"
else
    echo "1. no GEM screen file found ($E1) — nothing to do"
fi
# a .prev / staged leftovers from any version, too
for _left in cluster-map.esd.prev .cluster-map.new; do
    [ -f "$APP/eso/hmi/engdefs/$_left" ] && {
        rm -f "$APP/eso/hmi/engdefs/$_left"
        echo "   removed leftover: $_left"
    }
done

# ---- 2. supervisor config restore ---------------------------------------
CFG="$SYS/etc/eso/production/smartphone_integrator.json"
PERSISTENT_BACKUP="$CFG.gal-dualscreen.original"
RESTORED=0
if [ -f "$CFG" ]; then
    if grep -q "libgal_hook.so" "$CFG" 2>/dev/null; then
        if [ -r "$PERSISTENT_BACKUP" ]; then
            cp "$PERSISTENT_BACKUP" "$CFG" && {
                echo "2. restored $CFG from the unit-side backup"
                RESTORED=1
            }
        elif [ -n "$CARD" ] && [ -r "$CARD/mod/cluster_map_aa_greenmenu/backups/smartphone_integrator.json.original" ]; then
            cp "$CARD/mod/cluster_map_aa_greenmenu/backups/smartphone_integrator.json.original" "$CFG" && {
                echo "2. restored $CFG from the card backup"
                RESTORED=1
            }
        fi
        if [ "$RESTORED" = 0 ]; then
            echo "2. CRITICAL: config still carries the hook line and no"
            echo "   intact backup was found; it is left EXACTLY as it is."
            echo "   (Report the contents of $CFG to recover it manually.)"
        fi
    else
        echo "2. config has no hook line — Gal was not preloaded; nothing to do"
    fi
else
    echo "2. no supervisor config found at $CFG (check the system view)"
fi

# ---- 3. hook files -------------------------------------------------------
for _f in "$APP/eso/lib/gal_dualscreen" "$APP/eso/lib/libdmdt_flush.so"; do
    if [ -e "$_f" ]; then
        rm -rf "$_f" && echo "3. removed: $_f"
    fi
done
# run-time state/flag files our hook writes under /tmp (harmless next boot,
# but a clean slate is clearer after a revert)
rm -f /tmp/clustermap_last_paths /tmp/awk_state /tmp/patch_dbg \
      /tmp/stream-player.zoom /tmp/gal_uiconfig /tmp/gal_nav_info 2>/dev/null

# ---- 4. lsd.sh jar line + markers ----------------------------------------
LSD_PATH=""
for _cand in "$APP/eso/hmi/lsd/lsd.sh"; do
    [ -f "$_cand" ] && { LSD_PATH="$_cand"; break; }
done
if [ -n "$LSD_PATH" ] && grep -q "NavActiveIgnore.jar" "$LSD_PATH" 2>/dev/null; then
    # remove exactly the boot-time line our installer added
    cp -p "$LSD_PATH" "$LSD_PATH.pre-RevertAA" 2>/dev/null
    sed -i '/NavActiveIgnore\.jar/d' "$LSD_PATH"
    echo "4. removed the NavActiveIgnore.jar line from $LSD_PATH"
    echo "   (unit-side copy kept as lsd.sh.pre-RevertAA)"
fi
for _m in .aacluster_navignore_added .aacluster_tbt_added; do
    if [ -f "$APP/eso/hmi/lsd/$_m" ]; then
        rm -f "$APP/eso/hmi/lsd/$_m" && echo "4. removed marker: $_m"
    fi
done

# ---- finish ----------------------------------------------------------------
sync 2>/dev/null || true
echo ""
echo "#------------------------------------------------------------------"
echo "# revert_aa_hook finished."
echo "# Power-cycle the unit now (hold the power button ~10s)."
echo "# Afterwards the GEM must come up with your M.I.B. content intact;"
echo "# FEC/coding/customisations were not touched."
echo "#------------------------------------------------------------------"
trap 2
exit 0
