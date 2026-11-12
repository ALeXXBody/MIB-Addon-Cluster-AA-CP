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

# Console narration is mirrored into ONE capture file, so the diagnostic
# bundle below can carry the reason for an EARLY stop too (the install step
# itself is only reached at the end; a screen-generation failure must still
# leave evidence). say() is the only writer of console text in this script.
CM_DIAG_DIR=/tmp/clustermap_diag
mkdir -p "$CM_DIAG_DIR" 2>/dev/null
CM_CONSOLE_LOG="$CM_DIAG_DIR/console.log"
( : > "$CM_CONSOLE_LOG" ) 2>/dev/null   # subshell: dash exits the WHOLE script when a special builtin's redirect fails
say() { echo "$@"; echo "$@" >> "$CM_CONSOLE_LOG" 2>/dev/null; }
OUT=""
SD=""
PAYLOAD_NAME=""
_FINISHED=""

# EVERY exit path delivers the diagnostic file: the owner must always be able
# to send one file, and it must contain the reason the run stopped.
finish() {
	_rc=$1
	if [ -z "$_FINISHED" ]; then
		_FINISHED=1
		_DC=""
		if [ -n "$SD" ] && [ -n "$PAYLOAD_NAME" ] && \
		   [ -r "$SD/$PAYLOAD_NAME/greenmenu/diag_collect.sh" ]; then
			_DC="$SD/$PAYLOAD_NAME/greenmenu/diag_collect.sh"
		fi
		# Combine the install log (if the step ran) with THIS script's
		# narration, and hand that to the collector as the run summary.
		_CMB="$CM_DIAG_DIR/run_combined.log"
		{
			[ -n "$OUT" ] && [ -r "$OUT" ] && cat "$OUT"
			echo ""
			echo "== custom.sh console (run narration)"
			[ -n "$OUT" ] && [ -r "$OUT" ] || \
				echo "(the install step was never reached)"
			cat "$CM_CONSOLE_LOG" 2>/dev/null
		} > "$_CMB" 2>/dev/null
		if [ -n "$_DC" ]; then
			# -v: the collector narrates the delivery on the console — the
			# bundle path, and the TRUTH about the card copy (silence there
			# is how a missing diag.txt became a mystery in v0.4.21).
			sh "$_DC" append-run "$_CMB" -v
		else
			# No payload reachable: still leave a file on the unit.
			mkdir -p "$CM_DIAG_DIR" 2>/dev/null
			{
				echo "Cluster Map add-on diagnostic bundle"
				echo "run stopped before the payload could be located"
				echo ""
				cat "$CM_CONSOLE_LOG" 2>/dev/null
			} > "$CM_DIAG_DIR/diag.txt" 2>/dev/null
		fi
		if [ -z "$_DC" ]; then
			say "Send me this ONE file: $CM_DIAG_DIR/diag.txt"
		fi
	fi
	trap 2
	exit $_rc
}
# 0 == EXIT in POSIX sh. Any abrupt return still produces the bundle.
trap 'finish $?' 0

say "M.I.B. - More Incredible Bash - "
cat /net/mmx/fs/sda0/VERSION 2>/dev/null >> "$CM_CONSOLE_LOG"
cat /net/mmx/fs/sda0/VERSION 2>/dev/null
say "Cluster Map — Android Auto to Virtual Cockpit (mib-cluster-map mod)"
say ""

if [ -f /net/rcc/dev/shmem/reboot.mib ] || [ -f /net/rcc/dev/shmem/flash.mib ]; then
	say "Some process is already running in background, don't interrupt!"
	_FINISHED=1   # not an install run: no diagnostic bundle needed
	trap 2
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
	for rel in mod/cluster_aa mod/cluster_map_aa_greenmenu ClusterMap cluster_map_aa_greenmenu mod/ClusterMap; do
		if [ -f "$v/$rel/greenmenu/cluster-map.esd" ]; then
			SD=$v
			break
		fi
	done
	[ -n "$SD" ] && break
done
if [ -z "$SD" ]; then
	say "FAIL: mod/cluster_aa (or mod/cluster_map_aa_greenmenu) was not"
	say "found on the SD card. Copy the zip's 'mod/' folder to the card."
	trap 2
	exit 1
fi
PAYLOAD_NAME=mod/cluster_aa
[ -d "$SD/mod/cluster_aa" ] || PAYLOAD_NAME=mod/cluster_map_aa_greenmenu
say "Mod payload found: $SD/$PAYLOAD_NAME"
if [ -r "$SD/$PAYLOAD_NAME/VERSION" ]; then
	_v=
	read _v < "$SD/$PAYLOAD_NAME/VERSION" 2>/dev/null
	say "payload version: $_v"
fi
say ""

# 2. Register the screen on the unit: copy the mod's own emerald 'screen def'
#    file into the unit's engdefs/ folder (exactly what M.I.B.'s apps/launcher
#    does for its own menu file, and what the sshd mod does). It survives
#    reboots; the fork's uninstall removes it again.
#
# RULE — DO NOT MESS WITH GEM BY DEFAULT: a screen registration is exactly
# the write that can hang the engineering menu's next boot, with no undo
# available from the card. So the install DOES NOT touch engdefs unless the
# owner explicitly armed it: an empty file named HOOK_ARMED inside
# mod/cluster_aa/ on the card. Arming registers the screen
# AND lights the hook up in one known, deliberate step; without it the
# install stages files only, writes unit settings nowhere, and the GEM's
# own files stay byte-identical.
GEM_ARMED=0
[ -f "$SD/$PAYLOAD_NAME/HOOK_ARMED" ] && GEM_ARMED=1
[ -f "$SD/$PAYLOAD_NAME/ARMNOW.TXT" ] && GEM_ARMED=1
# An unarmed run says NOTHING here on the console: the GEM stays untouched
# and the silent default is not console talk. The arming how-to lives in
# the diag bundle (diag.txt, arm-state section), not on the screen.
ENGDEFS=""
if [ "$GEM_ARMED" = 1 ]; then
# WHICH VIEW the unit's engdefs lives under, per console node: MHI2 mounts
# print as /net/mmx.mibhigh.net/dev/... — a console node may address the app
# partition ONLY through that FQDN spelling; the /net/mmx/... shorthand and
# the local /mnt/app alias are not guaranteed to exist where this script
# runs. So: try every spelling, and choose only the one that is REACHABLE
# and WRITABLE (probed through the same spelling). Always print which one
# won — the console photo then answers view questions on its own.
# The probe is a FILE WRITE through the spelling we will write through
# (the unit ALSO refuses `mkdir` where a file write succeeds - diag
# 2026-11-08: "mkdir: /tmp/...: Function not implemented"), and engdefs
# may itself be missing in one view but present in another.
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
	mount -uw "$_v" 2>/dev/null
	_edefs="$_v/eso/hmi/engdefs"
	mkdir "$_edefs" 2>/dev/null
	[ -d "$_edefs" ] || continue
	if ( : > "$_edefs/.clustermap_probe" ) 2>/dev/null; then
		rm -f "$_edefs/.clustermap_probe" 2>/dev/null
		ENGDEFS="$_edefs"
		say "engdefs: writable via '$_v'"
		break
	fi
done
if [ -z "$ENGDEFS" ]; then
	# No view passed the probe. Prefer an engdefs that actually EXISTS through
	# any spelling (the owner's diag: the FQDN alias could exist while the
	# registered file lived elsewhere - writes into a non-existent dir only
	# confuse the diagnosis with "cp: No such file"). Never invent a path.
	for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
		if [ -d "$_v/eso/hmi/engdefs" ]; then
			ENGDEFS="$_v/eso/hmi/engdefs"
			break
		fi
	done
	if [ -z "$ENGDEFS" ]; then
		ENGDEFS=/net/mmx.mibhigh.net/mnt/app/eso/hmi/engdefs
		mkdir "$ENGDEFS" 2>/dev/null
	fi
	say "engdefs: NO view accepted a write through the probe (tried the FQDN,"
	say "shorthand, rcc and local spellings); trying the existing folder at"
	say "$ENGDEFS - the copy below reports what actually fails."
fi
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
if [ "$GEM_ARMED" = 1 ]; then
# CAR FACT (owner, v0.4.24 diag): the GEM (the process that parses engdefs
# and runs screen scripts) addresses the card in slot 1 as the QNET
# spelling /net/mmx/fs/sda0 — exactly the prefix M.I.B.'s own screens use.
# The console running us may see the same card as /fs/sda0; a screen with
# THAT spelling parses fine but every button then answers "Script not
# found" inside the GEM. So: the screen paths use the spelling the GEM can
# EXECUTE, never merely a view the console can read.
GEN_PREFIX="/net/mmx/fs/sda0/$PAYLOAD_NAME/greenmenu/"
if [ -f "$GEN_PREFIX/menus.sh" ]; then
	say "screen paths: GEM view (/net/mmx/fs/sda0)"
else
	GEN_PREFIX="$SD/$PAYLOAD_NAME/greenmenu/"
	say "screen paths: the view this console found the payload under ($SD)"
fi
TPL="$SD/$PAYLOAD_NAME/greenmenu/cluster-map.template.esd"
GEN_PATH=""
if [ -f "$TPL" ]; then
	GEN_PATH=/tmp/cluster-map.gen
	GEN_ERR="0"
	sed "s|@GREENMENU@|$GEN_PREFIX|g" "$TPL" \
		> "$GEN_PATH"
	# 1. non-empty
	if [ ! -s "$GEN_PATH" ]; then
		say "    ERROR: the generated file is EMPTY; keeping the unit's"
		say "           current screen file untouched on the unit."
		GEN_ERR=1
	fi
	# 2. the screen itself and no unresolved placeholder
	if [ "$GEN_ERR" = 0 ] && ! grep -q "screen ClusterMap" "$GEN_PATH"; then
		say "    ERROR: the generated file has no 'screen ClusterMap'; the"
		say "           unit's current screen file is kept untouched."
		GEN_ERR=1
	fi
	if [ "$GEN_ERR" = 0 ] && grep -q "@GREENMENU@" "$GEN_PATH"; then
		say "    ERROR: generation left an unreplaced @GREENMENU@ placeholder;"
		say "           keeping the unit's current screen file untouched."
		GEN_ERR=1
	fi
	# 3. every script path the screen names must exist on the card NOW
	if [ "$GEN_ERR" = 0 ]; then
		sed -n 's,^.*"\(/net/[^"]*\.sh\)[^"]*".*,\1,p' "$GEN_PATH" \
			| while IFS= read -r sp; do
			sp=${sp%% *}
			case "$sp" in */esd/scripts/*) continue ;; esac
			if [ ! -f "$sp" ]; then
				say "    MISSING on the card: $sp"
			fi
		done | grep -q "MISSING on the card" && GEN_ERR=1
		if [ "$GEN_ERR" = 1 ]; then
			say "    ERROR: the generated screen names scripts that are NOT on"
			say "           the card (run the paths-check above); keeping the"
			say "           unit's current screen file untouched."
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
		say "  GEM screen generated from the card: $ENGDEFS/cluster-map.esd"
		say "  (previous screen kept as cluster-map.esd.prev)"
	else
		rm -f "$GEN_PATH" 2>/dev/null
		say "  FAIL: the unit's engdefs file was NOT touched (GEM-boot safety)."
		say "        Re-copy the zip's whole mod/ folder and run this screen"
		say "        again; if this repeats, send this console photo."
		trap 2
		exit 1
	fi
else
	# No template on the card: the pre-built screen is the source, with the
	# same verify-then-replace dance -- BUT its hardcoded /net/mmx/fs/sda0
	# prefix is rewritten to the view this console actually found the payload
	# under ($SD), exactly like the template generation does.
	BUILT="$SD/$PAYLOAD_NAME/greenmenu/cluster-map.esd"
	if [ ! -s "$BUILT" ] || ! grep -q "screen ClusterMap" "$BUILT"; then
		say "FAIL: the card's pre-built cluster-map.esd is missing/incomplete."
		say "Re-copy the zip's whole mod/ folder and run this screen again."
		trap 2
		exit 1
	fi
	GEN_PATH=/tmp/cluster-map.gen
	if [ "$GEN_PREFIX" = "/net/mmx/fs/sda0/$PAYLOAD_NAME/greenmenu/" ]; then
		# the built prefix IS the GEM-canonical one: keep it byte-exact
		cat "$BUILT" > "$GEN_PATH"
	else
		sed "s|/net/mmx/fs/sda0/mod/[^/]*/greenmenu/|$GEN_PREFIX|g" \
			"$BUILT" > "$GEN_PATH"
	fi
	BUILD_ERR=0
	if [ ! -s "$GEN_PATH" ] || ! grep -q "screen ClusterMap" "$GEN_PATH"; then
		say "ERROR: the pre-built screen's rewrite failed; keeping the"
		say "       unit's current screen file untouched."
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
			say "ERROR: the pre-built screen names scripts that are NOT on"
			say "       the card; keeping the unit's current screen file"
			say "       untouched. See the MISSING lines above."
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
		say "  GEM screen installed from the card's built file: $ENGDEFS/cluster-map.esd"
		say "  (previous screen kept as cluster-map.esd.prev)"
	else
		rm -f "$GEN_PATH" 2>/dev/null
		say "  FAIL: the unit's engdefs file was NOT touched (GEM-boot safety)."
		say "        Re-copy the zip's whole mod/ folder and run this screen"
		say "        again; if this repeats, send this console photo."
		trap 2
		exit 1
	fi
fi   # if [ -f "$TPL" ]
say "GEM screen installed on the unit: $ENGDEFS/cluster-map.esd"
say ""

# 2b. Sanity: the screen file lists script files on the card. If GEM shows
#     "Script not found: .../greenmenu/<name>" after the install, the card's
#     copy of this repository is older or incomplete. One line, not a page.
_missing=""
for f in greenmenu/status.sh greenmenu/install.sh greenmenu/keep_map.sh \
         greenmenu/zoom.sh greenmenu/card_clear.sh greenmenu/navstrip.sh \
         greenmenu/menus.sh greenmenu/collect_for_porting.sh \
         greenmenu/collect_for_porting_full.sh scripts/lib_app_mount.sh \
         scripts/gal_dualscreen.default.conf; do
	[ -f "$SD/$PAYLOAD_NAME/$f" ] || _missing="$_missing $f"
done
# the GEM entries: every wrapper the shipped screen names must be there
if [ -d "$SD/$PAYLOAD_NAME/greenmenu/gem" ]; then
	for f in "$SD"/"$PAYLOAD_NAME"/greenmenu/gem/*.sh; do
		[ -f "$f" ] || _missing="$_missing $f"
	done
else
	_missing="$_missing greenmenu/gem/*.sh"
fi
[ -n "$_missing" ] && say "NOTE: card copy is incomplete (missing:$_missing)." \
	"Re-copy the zip's mod/ folder."
say ""
fi   # GEM_ARMED

# 3. Run the mod's own installer (status checks, gal profile check, hook +
#    player install — the same script the new screen's 'Install' entry runs).
#    The FULL output goes into the log (and into diag.txt); the CONSOLE gets
#    only the curated story lines, so the GEM screen stays short.
OUT=/tmp/cm_custom.log
sh "$SD/$PAYLOAD_NAME/greenmenu/install.sh" > "$OUT" 2>&1
RESULT=$?
_CS="$SD/$PAYLOAD_NAME/greenmenu/console_summary.sh"
if [ -r "$_CS" ]; then sh "$_CS" "$OUT"; else cat "$OUT"; fi
# Same verdict contract as GEM presses (menus.sh run_quiet): DONE/STOPPED +
# next instruction, plus ERROR lines on failure. The one-click flow skipped
# this, so its failures never got a verdict.
_VR=0
_VS="$SD/$PAYLOAD_NAME/greenmenu/run_verdict.sh"
if [ -r "$_VS" ]; then sh "$_VS" install "$OUT"; _VR=$?; fi
if [ "$_VR" -ne 0 ]; then
    echo "-- the run's ERROR lines:"
    if [ -r "$_CS" ]; then sh "$_CS" "$OUT"; fi
fi

okcount=0
# The same files under every app-partition view the unit can expose:
# local /mnt/app, the QNET FQDN spelling, the shorthand, and the rcc core.
for _view in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
	for u in "$_view/eso/lib/gal_dualscreen/profiles.conf" \
	         "$_view/eso/lib/gal_dualscreen/libgal_hook.so" \
	         "$_view/eso/lib/gal_dualscreen/gal_dualscreen.conf" \
	         "$_view/navigation/stream-player"; do
		[ -r "$u" ] && okcount=$((okcount+1))
	done
done
say ""
if [ "$okcount" -ge 4 ]; then
	say "Unit files: present (detail in diag.txt)."
else
	say "Unit files: not present on the unit yet (hook stays stock; detail in diag.txt)."
fi
# Is the hook ALREADY live on this unit (an earlier armed install)? Then an
# unarmed run is a no-op on the live state and must say exactly that.
_HOOKLIVE=0
for _v in /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /mnt/system /net/rcc/mnt/system; do
	_c="$_v/etc/eso/production/smartphone_integrator.json"
	if [ -r "$_c" ] && grep -q 'libgal_hook.so' "$_c" 2>/dev/null; then
		_HOOKLIVE=1; break
	fi
done
if [ "$GEM_ARMED" != 1 ] && [ "$_HOOKLIVE" = 1 ]; then
	say "Map already live on this unit (hook was armed earlier); nothing"
	say "changed. Detail in the diag file below."
elif [ "$GEM_ARMED" != 1 ]; then
	# The truth, in one line: files are staged but nothing is live yet.
	say "Staged only (not armed): the map is not live until HOOK_ARMED is"
	say "present on the card. Detail + how to arm: the diag file below."
elif grep -q -e "CLUSTERMAP_INSTALL_OK" -e "CLUSTERMAP_TURN_BY_TURN_OK" $OUT; then
	say "Map install: DONE. Reboot the unit (power button ~10 s), reconnect"
	say "the phone, and the map is on the cluster."
else
	say "Map install: FAILED - the reason follows (the summary above can"
	say "miss it; the run log never lies):"
	# The v0.7.5 car round proved the curated summary can MISS the failing
	# line ("Generated supervisor config failed jsonlint" and friends start
	# with words the summary did not know). Never promise the reason is
	# somewhere else: print the end of the run log right here.
	tail -n 8 "$OUT" | sed 's/^/  | /' >> "$CM_CONSOLE_LOG" 2>/dev/null
	tail -n 8 "$OUT" | sed 's/^/  | /'
fi
say ""

# The bundle (unit state + full run log + this narration) is written by
# finish(), which runs on EVERY exit path — early failures included.
finish $RESULT
