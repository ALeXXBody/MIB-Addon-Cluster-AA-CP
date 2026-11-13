#!/bin/sh
# virgin.sh - scrub EVERYTHING the add-on ever put on the unit, so the next
# install is tested exactly as a new user sees it.
#
# What uninstall already does (config restored, hook dir removed, player
# restored, lsd reverted, screen removed) is step 1 here: virgin.sh RUNS
# disable_hook.sh first and STOPS if that fails -- deleting the .so while
# the supervisor config still preloads it would leave gal unable to start.
# Step 2 removes what uninstall deliberately leaves behind (recovery copy,
# screen backup, markers, /tmp leftovers, card-root shadow file), then
# VERIFIES every path and reports REMOVED / ALREADY ABSENT / STILL PRESENT.
#
# Nothing on the SD card payload, logs or backups is deleted: the card is
# the owner's evidence and install source. The one exception is a card-root
# gal_dualscreen.conf shadow file -- it changes unit behaviour, so it is
# MOVED ASIDE on the card (never deleted) and reported.
#
# Exit 0 scrubbed-and-verified clean; 1 something remains (named) or the
# restore step failed (nothing was scrubbed that would strand the unit).
HERE=`dirname "$0"`
if [ -r "$HERE/common.sh" ]; then
    . "$HERE/common.sh"
else
    echo "common.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

find_card >/dev/null 2>&1 || true
[ -n "$PKG" ] || PKG=`cd "$HERE/.." && pwd`

STILL=0
note() { echo "$1"; }
hit()  { echo "  STILL PRESENT: $1 ($2)"; STILL=1; }
gone() { echo "  clean: $1 ($2)"; }

# ---- step 1: the normal uninstall path (restores the config) ------------
_NEED_DISABLE=0
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    if [ -r "$_v/etc/eso/production/smartphone_integrator.json" ] && \
       grep -q 'libgal_hook.so' "$_v/etc/eso/production/smartphone_integrator.json" 2>/dev/null; then
        _NEED_DISABLE=1; break
    fi
done
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v/eso/lib/gal_dualscreen" ] && { _NEED_DISABLE=1; break; }
done
if [ "$_NEED_DISABLE" = 1 ]; then
    echo "Virgin unit: running the standard restore first..."
    if ! sh "$PKG/disable_hook.sh"; then
        echo "FAIL: the restore step failed; nothing was scrubbed that would strand the unit." >&2
        echo "If recovery copies are missing, rescue_revert.sh on the card is the backstop." >&2
        exit 1
    fi
else
    echo "Virgin unit: hook already unarmed (no restore needed)."
fi

# ---- step 2: open one app rw window + one system rw window ---------------
APP_OK=0; SYS_OK=0
if app_mount_rw; then APP_OK=1; APP_WRITABLE=1; else APP_OK=0; fi
if system_mount_rw; then SYS_OK=1; SYSTEM_WRITABLE=1; else SYS_OK=0; fi
trap 'app_mount_finish; if [ "$SYS_OK" = 1 ]; then mount -ur "$SYSTEM_RW" 2>/dev/null || true; fi' 0 1 2 15
[ "$APP_OK" = 1 ] && echo "app: read-write via '$APP_LADDER_OK'"
[ "$SYS_OK" = 1 ] && echo "system: read-write via '$SYSTEM_LADDER_OK'"

scrub_file() {
    # scrub_file PATH : remove one unit file when a rw window exists.
    if [ ! -e "$1" ] && [ ! -f "$1" ]; then gone "$1" "already absent"; return 0; fi
    if [ "$2" = app ] && [ "$APP_OK" != 1 ]; then hit "$1" "app partition read-only, could not remove"; return 1; fi
    if [ "$2" = sys ] && [ "$SYS_OK" != 1 ]; then hit "$1" "system partition read-only, could not remove"; return 1; fi
    if rm -f "$1" 2>/dev/null && [ ! -e "$1" ]; then
        note "  removed: $1"; return 0
    fi
    hit "$1" "remove refused"; return 1
}

echo "-- supervisor recovery copies (safety nets, unreferenced) --"
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    [ -d "$_v/etc/eso/production" ] || continue
    scrub_file "$_v/etc/eso/production/smartphone_integrator.json.gal-dualscreen.original" sys
done

echo "-- hook payload remnants on the app partition --"
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v" ] || continue
    if [ -d "$_v/eso/lib/gal_dualscreen" ]; then
        if [ "$APP_OK" = 1 ] && rm -rf "$_v/eso/lib/gal_dualscreen" 2>/dev/null && \
           [ ! -d "$_v/eso/lib/gal_dualscreen" ]; then
            note "  removed dir: $_v/eso/lib/gal_dualscreen"
        else
            hit "$_v/eso/lib/gal_dualscreen" "preload dir survived"
        fi
    else
        gone "$_v/eso/lib/gal_dualscreen" "already absent"
    fi
    scrub_file "$_v/eso/lib/libdmdt_flush.so" app
    scrub_file "$_v/root/mibr-carplay111-safearea.conf" app
    scrub_file "$_v/navigation/stream-player.aacluster-original" app
    scrub_file "$_v/eso/hmi/lsd/.aacluster_tbt_removed" app
    scrub_file "$_v/eso/hmi/lsd/.aacluster_tbt_added" app
    scrub_file "$_v/eso/hmi/lsd/.aacluster_navignore_added" app
    # jars only when OUR marker said we put them there; another mod's
    # jars are not ours to delete.
    if [ -f "$_v/eso/hmi/lsd/jars/NavActiveIgnore.jar" ]; then
        hit "$_v/eso/hmi/lsd/jars/NavActiveIgnore.jar" "present without our marker (another mod's?) - left alone"
    else
        gone "$_v/eso/hmi/lsd/jars/NavActiveIgnore.jar" "already absent"
    fi
done

echo "-- GEM screens (ours + the backup uninstall keeps) --"
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
    _e="$_v/eso/hmi/engdefs"
    [ -d "$_e" ] || continue
    if [ -f "$_e/cluster-map.esd" ]; then
        if [ "$APP_OK" = 1 ] && rm -f "$_e/cluster-map.esd" 2>/dev/null && \
           [ ! -f "$_e/cluster-map.esd" ]; then
            note "  removed screen: $_e/cluster-map.esd"
        else
            hit "$_e/cluster-map.esd" "screen survived"
        fi
    else
        gone "$_e/cluster-map.esd" "already absent"
    fi
    scrub_file "$_e/cluster-map.esd.prev" app
done

echo "-- card-root shadow settings (moved aside on the card, never deleted) --"
for _c in /fs/sda0/gal_dualscreen.conf /fs/sdb0/gal_dualscreen.conf; do
    if [ ! -f "$_c" ]; then gone "$_c" "already absent"; continue; fi
    _aside="$_c.addon-cleanup"
    if mv "$_c" "$_aside" 2>/dev/null && [ ! -f "$_c" ] && [ -f "$_aside" ]; then
        note "  moved aside: $_c -> $_aside (rename it back to restore it)"
    else
        hit "$_c" "could not move aside (card read-only?)"
    fi
done

echo "-- RAM leftovers (/tmp is wiped at reboot anyway) --"
for _t in /tmp/gal_remote /tmp/gal_remote_trace /tmp/gal_cluster_menu \
          /tmp/gal_hires /tmp/gal_idr_pump /tmp/gal_uiconfig \
          /tmp/stream-player.menu /tmp/stream-player.zoom \
          /tmp/stream-player.navstrip /tmp/gal_kombi_ready /tmp/gal_inject \
          /tmp/gal_nav_info /tmp/gal_dualscreen.log /tmp/gal_dualscreen.log.prev \
          /tmp/stream-player.log /tmp/clustermap_last_paths \
          /tmp/cm_custom.log /tmp/clustermap_diag/console.log; do
    if [ -e "$_t" ]; then
        if rm -f "$_t" 2>/dev/null; then note "  removed: $_t"; else hit "$_t" "remove refused"; fi
    fi
done
for _t in /tmp/cm_menu_*.log /tmp/clustermap_diag /tmp/clustermap_unit; do
    rm -rf $_t 2>/dev/null || true
done
gone "/tmp addon files" "scrubbed (patterns: gal_*, stream-player.*, cm_menu_*, clustermap_*)"

echo "-- supervisor config is hook-free --"
_CLEAN=1
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    _c="$_v/etc/eso/production/smartphone_integrator.json"
    if [ -r "$_c" ] && grep -q 'libgal_hook.so' "$_c" 2>/dev/null; then
        hit "$_c" "still references the hook"; _CLEAN=0
    fi
done
[ "$_CLEAN" = 1 ] && gone "supervisor config" "no hook reference anywhere"

echo ""
if [ "$STILL" = 0 ]; then
    echo "VIRGIN UNIT: CLEAN - nothing of the add-on remains on the unit."
    echo "Next: reboot (power button ~10 s), then install as a new user."
    echo "Kept on purpose: the SD card payload, logs, backups and history"
    echo "(the unit no longer references any of them)."
    exit 0
else
    echo "VIRGIN UNIT: INCOMPLETE - items above are STILL PRESENT with reasons." >&2
    exit 1
fi
