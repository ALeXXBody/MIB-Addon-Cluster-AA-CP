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

echo "M.I.B. - More Incredible Bash - "
cat /net/mmx/fs/sda0/VERSION 2>/dev/null
echo "Cluster Map — Android Auto to Virtual Cockpit (mib-cluster-map mod)"
echo ""

if [ -f /net/rcc/dev/shmem/reboot.mib ] || [ -f /net/rcc/dev/shmem/flash.mib ]; then
	echo "Some process is already running in background, don't interrupt!"
	exit 0
fi

# --------------------------- ADDON CODE ------------------------------------

# 1. Find the mod payload on the card (slot 1 or slot 2).
# Same discovery philosophy as the mod's greenmenu/common.sh find_card():
# the card can appear under any local or network view, and the payload in
# any of the known layouts. The mount table is tried first.
SD=""
SDCANDS=`mount 2>/dev/null | sed -n "s|^.* on \(/[^ ]*\) .*|\1|p"`
SDCANDS="$SDCANDS /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0"
for v in $SDCANDS; do
	if [ -d "$v" ] || [ -f "$v" ]; then :; else continue; fi
	for rel in mod/cluster_map_aa_greenmenu ClusterMap cluster_map_aa_greenmenu mod/ClusterMap; do
		if [ -f "$v/$rel/greenmenu/cluster-map.esd" ]; then
			SD=$v
			break
		fi
	done
	[ -n "$SD" ] && break
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
# Generate the screen file FROM FIND_CARD'S RESULT: every GEM item's script
# path must name the card view this console actually sees — hardcoding
# /net/mmx/fs/sda0/... made the buttons break whenever the card's view
# changed (the "Script not found" screens). The template carries a
# @GREENMENU@ placeholder; the located path replaces it.
TPL="$SD/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.template.esd"
CONSOLE_ERRORS=""
if [ -f "$TPL" ]; then
	# the view this console itself resolved the payload under: prefer the
	# payload path EXACTLY as custom.sh found it ($SD), not the fixed forms
	GEN=`sed "s|@GREENMENU@|$SD/mod/cluster_map_aa_greenmenu/greenmenu/|g" "$TPL"`
	# verify every generated script file exists NOW; report the missing ones
	echo "  GEM screen paths check (from the template):"
	echo "$GEN" | while IFS= read -r ln; do
		case "$ln" in
			*value*0x0100\ *|*value*system*)
				continue ;;
			*)
				continue ;;
		esac
	done
	# (the real check: extract each quoted script path and test it)
	echo "$GEN" | sed -n 's,^.*"\(/net/[^"]*\.sh\)[^"]*".*,\1,p' | while IFS= read -r sp; do
		sp=${sp%% *}
		case "$sp" in */esd/scripts/*) continue ;; esac   # M.I.B.'s own scripts (reboot) live on the unit, not on our card
		if [ ! -f "$sp" ]; then
			echo "    MISSING on the card: $sp"
			CONSOLE_ERRORS=1
		fi
	done
	echo "$GEN" > "$ENGDEFS/cluster-map.esd"
	echo "  GEM screen generated from the card: $ENGDEFS/cluster-map.esd"
else
	cp -p "$SD/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.esd" \
	"$ENGDEFS/cluster-map.esd" || {
	echo "FAIL: could not write $ENGDEFS/cluster-map.esd"
	echo "(Is M.I.B. installed? It creates/maintains that folder.)"
	trap 2
	exit 1
	}
fi
echo "GEM screen installed on the unit: $ENGDEFS/cluster-map.esd"
echo ""

# 2b. Sanity: the screen file lists script files on the card. If GEM shows
#     "Script not found: /net/mmx/fs/sda0/mod/…/greenmenu/<name>" after the
#     install, the card's copy of this repository is older or incomplete —
#     the screen on the unit came from the card, so the two disagree only
#     when the card lost files. Check the ones the screen points at:
for f in greenmenu/status.sh greenmenu/install.sh greenmenu/keep_map.sh \
         greenmenu/zoom.sh greenmenu/card_clear.sh greenmenu/navstrip.sh; do
	if [ ! -f "$SD/mod/cluster_map_aa_greenmenu/$f" ]; then
		echo "NOTE: missing on the card: mod/cluster_map_aa_greenmenu/$f"
		echo "      -> copy this repository's whole 'mod/' folder onto the card"
		echo "         again, THEN re-run this screen. GEM would otherwise print"
		echo "         'Script not found' for the missing item."
	fi
done
echo ""

# 3. Run the mod's own installer (status checks, gal profile check, hook +
#    player install — the same script the new screen's 'Install' entry runs).
#    Output is captured so the tail message can reflect the real result.
OUT=/tmp/cm_custom.log
sh "$SD/mod/cluster_map_aa_greenmenu/greenmenu/install.sh" > $OUT 2>&1
RESULT=$?
cat $OUT

echo ""
echo "--- install self-check (unit files) --------------------------------"
okcount=0
for u in /mnt/app/eso/lib/gal_dualscreen/profiles.conf \
         /mnt/app/eso/lib/gal_dualscreen/libgal_hook.so \
         /mnt/app/eso/lib/gal_dualscreen/gal_dualscreen.conf \
         /mnt/app/navigation/stream-player \
         /net/mmx/mnt/app/eso/lib/gal_dualscreen/profiles.conf \
         /net/mmx/mnt/app/eso/lib/gal_dualscreen/libgal_hook.so \
         /net/mmx/mnt/app/navigation/stream-player; do
	if [ -r "$u" ]; then
		echo "  ok: $u"
		okcount=$((okcount+1))
	fi
done
if [ "$okcount" -ge 4 ]; then
	echo "  self-check: the unit files are in place (seen through one or"
	echo "  more of the app-partition views)."
else
	echo "  self-check: the unit files are NOT in place yet. That means the"
	echo "  app/system partitions could not be remounted read-write from"
	echo "  this console context. The mount ladder inside the installer"
	echo "  tries every form (plain /net on -f mmx/rcc). If the files stay"
	echo "  absent, send this photo - the hook will stay stock until the"
	echo "  files exist."
fi
echo ""
if grep -q -e "CLUSTERMAP_INSTALL_OK" -e "CLUSTERMAP_TURN_BY_TURN_OK" $OUT; then
	echo "Install finished. Reboot the unit (hold the power button for 10"
	echo "seconds), then open the Green Engineering Menu again: the new"
	echo "'ClusterMap' screen is at the top level of the menu."
else
	echo "Install did NOT finish (see the messages above). The most"
	echo "common causes are named there; if a 'read-only' note points at"
	echo "the card, unlock the card's LOCK slider / reformat FAT32 / run"
	echo "chkdsk /f on the card. The install itself no longer stops on a"
	echo "read-only card: backups/logs then go to /tmp and are only kept"
	echo "until the next reboot, so fix the card and re-run this screen."
fi
echo ""

trap 2
exit $RESULT
