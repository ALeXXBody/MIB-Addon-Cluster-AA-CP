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
#
# WHICH VIEW the unit's engdefs lives under, per console node: MHI2 mounts
# print as /net/mmx.mibhigh.net/dev/... — a console node may address the app
# partition ONLY through that FQDN spelling; the /net/mmx/... shorthand and
# the local /mnt/app alias are not guaranteed to exist where this script
# runs. So: try every spelling, and choose only the one that is REACHABLE
# and WRITABLE (probed through the same spelling). Always print which one
# won — the console photo then answers view questions on its own.
ENGDEFS=""
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
	[ -d "$_v/eso/hmi/engdefs" ] || continue
	mount -uw "$_v" 2>/dev/null
	if mkdir "$_v/eso/hmi/.clustermap_probe" 2>/dev/null; then
		rmdir "$_v/eso/hmi/.clustermap_probe" 2>/dev/null
		ENGDEFS=$_v/eso/hmi/engdefs
		echo "engdefs: writable via '$_v'"
		break
	fi
done
if [ -z "$ENGDEFS" ]; then
	ENGDEFS=/net/mmx.mibhigh.net/mnt/app/eso/hmi/engdefs
	echo "engdefs: NO view accepted writes (tried the FQDN, shorthand, rcc and"
	echo "local spellings of the app partition); the screen step will report"
	echo "exactly what failed below."
fi
# Generate the screen file FROM FIND_CARD'S RESULT: every GEM item's script
# path must name the card view this console actually sees — hardcoding
# /net/mmx/fs/sda0/... made the buttons break whenever the card's view
# changed (the "Script not found" screens). The template carries a
# @GREENMENU@ placeholder; the located path replaces it.
#
# GEM-boot safety contract (this install has no undo available: GEM parses
# engdefs at every boot): the LIVE engdefs file is NEVER truncated with
# unverified content. The new file is staged NEXT to the live one, checked
# byte-for-byte on the rules below, and only then renamed in place. A
# previous good copy is kept as cluster-map.esd.prev.
TPL="$SD/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.template.esd"
GEN_PATH=""
if [ -f "$TPL" ]; then
	GEN_PATH="$SD/mod/cluster_map_aa_greenmenu/greenmenu/.cluster-map.gen"
	GEN_ERR="0"
	echo "  GEM screen paths check (from the template):"
	sed "s|@GREENMENU@|$SD/mod/cluster_map_aa_greenmenu/greenmenu/|g" "$TPL" \
		> "$GEN_PATH"
	# 1. non-empty
	if [ ! -s "$GEN_PATH" ]; then
		echo "    ERROR: the generated file is EMPTY; keeping the unit's"
		echo "           current screen file untouched on the unit."
		GEN_ERR=1
	fi
	# 2. the screen itself and no unresolved placeholder
	if [ "$GEN_ERR" = 0 ] && ! grep -q "screen ClusterMap" "$GEN_PATH"; then
		echo "    ERROR: the generated file has no 'screen ClusterMap'; the"
		echo "           unit's current screen file is kept untouched."
		GEN_ERR=1
	fi
	if [ "$GEN_ERR" = 0 ] && grep -q "@GREENMENU@" "$GEN_PATH"; then
		echo "    ERROR: generation left an unreplaced @GREENMENU@ placeholder;"
		echo "           keeping the unit's current screen file untouched."
		GEN_ERR=1
	fi
	# 3. every script path the screen names must exist on the card NOW
	if [ "$GEN_ERR" = 0 ]; then
		sed -n 's,^.*"\(/net/[^"]*\.sh\)[^"]*".*,\1,p' "$GEN_PATH" \
			| while IFS= read -r sp; do
			sp=${sp%% *}
			case "$sp" in */esd/scripts/*) continue ;; esac
			if [ ! -f "$sp" ]; then
				echo "    MISSING on the card: $sp"
			fi
		done | grep -q "MISSING on the card" && GEN_ERR=1
		if [ "$GEN_ERR" = 1 ]; then
			echo "    ERROR: the generated screen names scripts that are NOT on"
			echo "           the card (run the paths-check above); keeping the"
			echo "           unit's current screen file untouched."
		fi
	fi
	if [ "$GEN_ERR" = 0 ]; then
		# verified: stage NEXT TO the live file (same filesystem as the
		# unit's parse) and rename in place — previous copy kept as .prev.
		rm -f "$ENGDEFS/cluster-map.esd.prev" 2>/dev/null
		if [ -f "$ENGDEFS/cluster-map.esd" ]; then
			cp -p "$ENGDEFS/cluster-map.esd" "$ENGDEFS/cluster-map.esd.prev" || true
		fi
		cp -p "$GEN_PATH" "$ENGDEFS/.cluster-map.new" && \
			mv "$ENGDEFS/.cluster-map.new" "$ENGDEFS/cluster-map.esd"
		rm -f "$GEN_PATH" 2>/dev/null
		sync 2>/dev/null || true
		echo "  GEM screen generated from the card: $ENGDEFS/cluster-map.esd"
		echo "  (previous screen kept as cluster-map.esd.prev)"
	else
		rm -f "$GEN_PATH" 2>/dev/null
		echo "  FAIL: the unit's engdefs file was NOT touched (GEM-boot safety)."
		echo "        Re-copy the zip's whole mod/ folder and run this screen"
		echo "        again; if this repeats, send this console photo."
		trap 2
		exit 1
	fi
else
	# No template on the card: the pre-built screen is the source, with the
	# same verify-then-replace dance -- BUT its hardcoded /net/mmx/fs/sda0
	# prefix is rewritten to the view this console actually found the payload
	# under ($SD), exactly like the template generation does.
	BUILT="$SD/mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.esd"
	if [ ! -s "$BUILT" ] || ! grep -q "screen ClusterMap" "$BUILT"; then
		echo "FAIL: the card's pre-built cluster-map.esd is missing/incomplete."
		echo "Re-copy the zip's whole mod/ folder and run this screen again."
		trap 2
		exit 1
	fi
	GEN_PATH="$SD/mod/cluster_map_aa_greenmenu/greenmenu/.cluster-map.gen"
	sed "s|/net/mmx/fs/sda0/mod/cluster_map_aa_greenmenu/greenmenu/|$SD/mod/cluster_map_aa_greenmenu/greenmenu/|g" \
		"$BUILT" > "$GEN_PATH"
	BUILD_ERR=0
	if [ ! -s "$GEN_PATH" ] || ! grep -q "screen ClusterMap" "$GEN_PATH"; then
		echo "ERROR: the pre-built screen's rewrite failed; keeping the"
		echo "       unit's current screen file untouched."
		BUILD_ERR=1
	fi
	if [ "$BUILD_ERR" = 0 ]; then
		sed -n 's,^.*"\(/net/[^"]*\.sh\)[^"]*".*,\1,p' "$GEN_PATH" \
			| while IFS= read -r sp; do
			sp=${sp%% *}
			case "$sp" in */esd/scripts/*) continue ;; esac
			if [ ! -f "$sp" ]; then echo "MISSING on the card: $sp"; fi
		done | grep -q "MISSING on the card" && BUILD_ERR=1
		if [ "$BUILD_ERR" = 1 ]; then
			echo "ERROR: the pre-built screen names scripts that are NOT on"
			echo "       the card; keeping the unit's current screen file"
			echo "       untouched. See the MISSING lines above."
		fi
	fi
	if [ "$BUILD_ERR" = 0 ]; then
		rm -f "$ENGDEFS/cluster-map.esd.prev" 2>/dev/null
		if [ -f "$ENGDEFS/cluster-map.esd" ]; then
			cp -p "$ENGDEFS/cluster-map.esd" "$ENGDEFS/cluster-map.esd.prev" || true
		fi
		cp -p "$GEN_PATH" "$ENGDEFS/.cluster-map.new" && \
			mv "$ENGDEFS/.cluster-map.new" "$ENGDEFS/cluster-map.esd"
		rm -f "$GEN_PATH" 2>/dev/null
		sync 2>/dev/null || true
		echo "  GEM screen installed from the card's built file: $ENGDEFS/cluster-map.esd"
		echo "  (previous screen kept as cluster-map.esd.prev)"
	else
		rm -f "$GEN_PATH" 2>/dev/null
		echo "  FAIL: the unit's engdefs file was NOT touched (GEM-boot safety)."
		echo "        Re-copy the zip's whole mod/ folder and run this screen"
		echo "        again; if this repeats, send this console photo."
		trap 2
		exit 1
	fi
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
# The same files under every app-partition view the unit can expose:
# local /mnt/app, the QNET FQDN spelling, the shorthand, and the rcc core.
for _view in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
	for u in "$_view/eso/lib/gal_dualscreen/profiles.conf" \
	         "$_view/eso/lib/gal_dualscreen/libgal_hook.so" \
	         "$_view/eso/lib/gal_dualscreen/gal_dualscreen.conf" \
	         "$_view/navigation/stream-player"; do
		if [ -r "$u" ]; then
			echo "  ok: $u"
			okcount=$((okcount+1))
		fi
	done
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
