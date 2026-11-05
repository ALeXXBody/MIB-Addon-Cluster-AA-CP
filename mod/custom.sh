#!/bin/sh
#
# mod/custom.sh — one-click install of the "Cluster Map — AA to Virtual Cockpit"
# mod payload (mod/cluster_map_aa_greenmenu/) inside M.I.B.'s Green Engineering
# Menu. NO file on the card or on the unit has to be edited by hand.
#
# How the owner runs it (pure copy-paste flow):
#   1. copy this whole repository's "mod/" folder onto the M.I.B. SD card,
#   2. in the car: hold MENU -> Testmode -> GEM ->
#      M.I.B. -> Advanced Settings -> "Run /mod/custom.sh from m.i.b. SD",
#   3. reboot the unit, open GEM -> the new top-level "ClusterMap" screen is there.
#
# What it does: copies the mod's own screen file (greenmenu/cluster-map.esd)
# into the unit's GEM screen folder (engdefs/) — the same mechanism M.I.B.
# itself uses to register its screens (apps/launcher links
# Launcher-sda0.esd into engdefs/) — then runs the mod's installer from the
# card, so everything is on the unit after this single click.
#
# Idempotent: re-running it just re-copies the screen file and re-runs the
# (already safe) installer. Uninstall stays available in the ClusterMap
# screen itself; it also removes the menu screen again.
#
# NOTE: this file is M.I.B.'s documented hook for user mods ("Run
# /mod/custom.sh from m.i.b. SD"). If another mod you use also ships a
# mod/custom.sh, append its commands below the "ADDON CODE" line instead of
# overwriting this one.
#

# Same environment every M.I.B. GEM screen script gets (see esd/scripts/custom.sh
# in M.I.B.'s own tree).
trap '' 2

export PATH=.:/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/media/grancenote/bin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin
export LD_LIBRARY_PATH=/lib:/mnt/app/root/lib-target:/eso/lib:/mnt/app/usr/lib:/mnt/app/armle/lib:/mnt/app/armle/lib/dll:/mnt/app/armle/usr/lib
unset LD_PRELOAD

echo -ne "M.I.B. - More Incredible Bash - "
cat /net/mmx/fs/sda0/VERSION 2>/dev/null
echo "Cluster Map — Android Auto to Virtual Cockpit (mib-cluster-map mod)"
echo ""

if [ -f /net/rcc/dev/shmem/reboot.mib ] || [ -f /net/rcc/dev/shmem/flash.mib ]; then
	echo "Some process is already running in background, don't interrupt!"
	exit 0
fi

# --------------------------- ADDON CODE ------------------------------------

# 1. Find the mod payload on the card (slot 1 or slot 2).
SD=""
for v in /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0; do
	if [ -f "$v/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.esd" ]; then
		SD=$v
		break
	fi
done
if [ -z "$SD" ]; then
	echo "FAIL: mod/cluster_map_aa_greenmenu/ was not found on the SD card."
	echo "Copy this repository's 'mod/' folder onto the M.I.B. SD card first."
	trap 2
	exit 1
fi
echo "Mod payload found: $SD/mod/cluster_map_aa_greenmenu"
echo ""

# 2. Register the screen on the unit: copy the mod's own emerald 'screen def'
#    file into the unit's engdefs/ folder (exactly what M.I.B.'s apps/launcher
#    does for its own menu file, and what the sshd mod does). It survives
#    reboots; the fork's uninstall removes it again.
ENGDEFS=/net/mmx/mnt/app/eso/hmi/engdefs
mount -uw /net/mmx/mnt/app 2>/dev/null
cp -p "$SD/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.esd" \
	"$ENGDEFS/cluster-map.esd" || {
	echo "FAIL: could not write $ENGDEFS/cluster-map.esd"
	echo "(Is M.I.B. installed? It creates/maintains that folder.)"
	trap 2
	exit 1
}
echo "GEM screen installed on the unit: $ENGDEFS/cluster-map.esd"
echo ""

# 3. Run the mod's own installer (status checks, gal profile check, hook +
#    player install — the same script the new screen's 'Install' entry runs).
#    Output is captured so the tail message can reflect the real result.
OUT=/tmp/cm_custom.log
sh "$SD/mod/cluster_map_aa_greenmenu/greenmenu/install.sh" > $OUT 2>&1
RESULT=$?
cat $OUT

echo ""
if grep -q -e "CLUSTERMAP_INSTALL_OK" -e "CLUSTERMAP_TURN_BY_TURN_OK" $OUT; then
	echo "Install finished. Reboot the unit (hold the power button for 10"
	echo "seconds), then open the Green Engineering Menu again: the new"
	echo "'ClusterMap' screen is at the top level of the menu."
else
	echo "Install did NOT finish (see the messages above — most often"
	echo "'NOT INSTALLED: the SD card is READ-ONLY to the unit': unlock the"
	echo "card's LOCK slider / reformat FAT32 / run chkdsk /f on the card)."
	echo "Fix it, push the card back in, and run this screen again."
fi
echo ""

trap 2
exit $RESULT
