#!/bin/sh
# diag_collect.sh — writes ONE bundle file on the card:
#   mod/cluster_map_aa_greenmenu/diag.txt
# The owner sends that single file; everything needed to diagnose an add-on
# problem or tune the map is inside it. It is written by every install,
# uninstall and settings run (see custom.sh / menus.sh), and can also run
# directly from M.I.B.'s own "Run custom script" as
#   mod/cluster_map_aa_greenmenu/greenmenu/diag_collect.sh
#
# Console behaviour: SILENT unless asked (diag_collect.sh -v). The bundle is
# the product; the GEM console stays readable.
#
# Sections and what they answer:
#   1 unit/train            - which firmware, is its train profile known
#   2 payload integrity     - unit-state + what the card actually carries
#   3 card views            - where the card sits, mount-table reality
#   4 unit view ladder      - which partition spelling the console can reach
#   5 arm state             - hook armed / GEM screen registered or not
#   6 engdefs listing       - GEM diagnostics WITHOUT touching those files
#   7 installed settings    - window, dpi, insets, aspect, zoom, full-frame
#   8 supervisor config     - which view serves it, env KEY NAMES only
#   9 hook log tail         - the hook's own events
#  10 install paths + notes - where the install wrote backups/logs
#  11 last run summary      - the filtered result lines of the recent run

HERE=`dirname "$0"`
PKG=`cd "$HERE/.." && pwd`
VERBOSE=${1:--}

# Portable helpers (the unit shell again: no printf/tr/diff bashisms).
OUT="$PKG/diag.txt"
TMP="$PKG/diag.tmp.$$"
: > "$TMP" || { echo "diag_collect: cannot write $TMP on the card" >&2; exit 1; }

SRC=`dirname "$0"`
. "$SRC/common.sh" 2>/dev/null || \
    { echo "diag_collect: common.sh missing" >> "$TMP"; }

APPVIEW=`app_pick_view 2>/dev/null || echo /mnt/app`
SYSVIEW=""
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    if [ -d "$_v/etc/eso/production" ]; then SYSVIEW="$_v"; break; fi
done
[ -n "$SYSVIEW" ] || SYSVIEW=/mnt/system

CFG=""
for _v in /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /mnt/system /net/rcc/mnt/system; do
    _f="$_v/etc/eso/production/smartphone_integrator.json"
    if [ -r "$_f" ] && grep -q 'LD_PRELOAD=' "$_f" 2>/dev/null; then
        CFG="$_f"; break
    fi
done
[ -n "$CFG" ] || for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    if [ -r "$_v/etc/eso/production/smartphone_integrator.json" ]; then
        CFG="$_v/etc/eso/production/smartphone_integrator.json"; break
    fi
done
[ -n "$CFG" ] || CFG="$SYSVIEW/etc/eso/production/smartphone_integrator.json"
CONF=""
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    if [ -r "$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf" ]; then
        CONF="$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf"; break
    fi
done
[ -n "$CONF" ] || CONF="$APPVIEW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
LOGCARD="$PKG/logs/gal_dualscreen.log"
LOGTMP=/tmp/gal_dualscreen.log

put() { echo "$1" >> "$TMP"; }
section() { echo "" >> "$TMP"; echo "== $1" >> "$TMP"; }

put "Cluster Map add-on diagnostic bundle"
put "collected: `date 2>/dev/null`"
put "payload: $PKG"

# ---- 1. unit / train
section "1 unit and firmware"
for f in /net/rcc/dev/shmem/version.txt /dev/shmem/version.txt; do
    if [ -r "$f" ]; then
        grep -e train -e "Current train" "$f" 2>/dev/null | head -2 >> "$TMP"
        break
    fi
done
[ -r "$PKG/profiles.conf" ] && \
    put "train supported: `sh "$HERE/../profile_check" "$PKG/profiles.conf" 2>/dev/null || echo 'profile_check not executable here (expected on the unit only)'`"

# ---- 2. payload integrity
section "2 payload files (cksum)"
if [ -d "$PKG" ]; then
    (cd "$PKG" && find . -type f -name '*.sh' -o -name '*.conf' -o -name '*.esd' -o -name '*.so' -o -name 'stream-player' -o -name 'profile_check' -o -name '*.jar' \
        | LC_ALL=C sort | while read -r f; do
            c=`cksum "$f" 2>/dev/null | awk '{print $1" "$2}'`
            echo "$c  $f"
        done) >> "$TMP" 2>/dev/null
else
    put "payload folder missing: $PKG"
fi

# ---- 3. card views
section "3 card views (mount table + payload)"
mount 2>/dev/null | grep -i -e sd0 -e sda -e sdb -e usb >> "$TMP" 2>/dev/null
put "payload at: $PKG (card view: $VOLUME)"
put "HOOK_ARMED marker: `([ -f "$PKG/HOOK_ARMED" ] && echo present) || echo absent`"

# ---- 4. unit view ladder
section "4 unit partition views"
put "app view:  $APPVIEW"
put "system view: $SYSVIEW"
put "jsonlint: `([ -x "$APPVIEW/eso/bin/jsonlint" ] && echo present) || echo missing`"
put "hook .so: `([ -x "$APPVIEW/eso/lib/gal_dualscreen/libgal_hook.so" ] && echo present) || echo absent`"

# ---- 5. arm state
section "5 arm state"
_PRELOAD="no"; _PRELOAD_AT=""
for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
    _f="$_v/etc/eso/production/smartphone_integrator.json"
    if [ -r "$_f" ] && grep -q 'LD_PRELOAD=' "$_f" 2>/dev/null; then
        _PRELOAD="YES"; _PRELOAD_AT="$_f"; break
    fi
done
put "hook preloaded into gal (config carries LD_PRELOAD): ${_PRELOAD}${_PRELOAD_AT:+ (in $_PRELOAD_AT)}"
put "engdefs/cluster-map.esd: `([ -d "${APPVIEW%\\0}/eso/hmi/engdefs" ] && [ -f "$APPVIEW/eso/hmi/engdefs/cluster-map.esd" ] && echo present) || echo not-registered`"

# ---- 6. engdefs listing (names only; the GEM's own world, not read)
section "6 engdefs listing (names)"
[ -d "$APPVIEW/eso/hmi/engdefs" ] && \
    ls "$APPVIEW/eso/hmi/engdefs" >> "$TMP" 2>/dev/null || put "(engdefs not reachable from this console view)"

# ---- 7. installed settings (the fine-tune facts)
section "7 installed settings (unit copy of gal_dualscreen.conf)"
if [ -r "$CONF" ]; then
    grep -e "^GAL_PLAYER_WINDOW" -e "^GAL_SECONDARY_DPI" -e "^GAL_SECONDARY_MARGINS" \
         -e "^GAL_SECONDARY_INSETS" -e "^GAL_SECONDARY_PIXEL_ASPECT_RATIO_E4" \
         -e "^GAL_SECONDARY_VIEWING_DISTANCE" -e "^GAL_PLAYER_ZOOM_E4" \
         -e "^CLUSTERMAP_FULL_FRAME" -e "^GAL_KEEP_MAP" -e "^GAL_SECONDARY_UI_CONFIG_HEX" \
         "$CONF" >> "$TMP" 2>/dev/null
else
    put "(no unit settings copy at $CONF)"
fi

# ---- 8. supervisor config env keys
section "8 supervisor config (env KEY names only; no values)"
_put_envs() {
    awk '
        /"children"/ { in_c=1 }
        in_c && /^[ \t]*"envs"/ {
            # pull only the entry names, not their values
            line=$0
            while (match(line, /"[A-Za-z0-9_]+=/)) {
                print "  " substr(line, RSTART+1, RLENGTH-2)
                line = substr(line, RSTART+RLENGTH)
            }
            exit
        }
    ' "$1" 2>/dev/null
}
if [ -r "$CFG" ]; then
    put "config view: $CFG"
    _put_envs "$CFG"
    put "persistent backup beside it: `([ -r "$CFG.gal-dualscreen.original" ] && echo present) || echo absent`"
else
    put "(supervisor config not reachable from this view: $CFG)"
fi

# ---- 9. hook log tail
section "9 hook log tail (last 120 lines)"
LOG=""
[ -r "$LOGCARD" ] && LOG="$LOGCARD"
[ -z "$LOG" ] && [ -r "$LOGTMP" ] && LOG="$LOGTMP"
if [ -n "$LOG" ]; then
    put "source: $LOG"
    tail -120 "$LOG" >> "$TMP" 2>/dev/null
else
    put "(no hook log found on the card at logs/gal_dualscreen.log, none in /tmp yet)"
fi

# ---- 10. install paths record
section "10 install home record"
[ -r "$PKG/last_install_paths.txt" ] && cat "$PKG/last_install_paths.txt" >> "$TMP" || \
    put "(no last_install_paths.txt)"
[ -r /tmp/clustermap_last_paths ] && cat /tmp/clustermap_last_paths >> "$TMP"

# ---- 11. last run summary (appended by custom.sh / menus.sh)
section "11 last run summary (curated result lines)"
if [ "$1" = append-run ] && [ -r "$2" ] && [ -n "$2" ]; then
    "$HERE/console_summary.sh" "$2" >> "$TMP" 2>/dev/null
fi
# (the caller appends after us)

# ---- 12. full log of the last operation (the pages the console used to)
section "12 full log of the last operation (capped at 400 lines)"
if [ "$1" = append-run ] && [ -r "$2" ] && [ -n "$2" ]; then
    head -400 "$2" >> "$TMP" 2>/dev/null
fi

# ---- deliver ----------------------------------------------------------------
# Keep the newest bundle plus one previous copy (so a run that went bad
# does not destroy the last good evidence):
[ -r "$OUT" ] && cp "$OUT" "$OUT.prev" 2>/dev/null
[ -s "$TMP" ] || echo "(empty bundle)" >> "$TMP"
mv "$TMP" "$OUT" 2>/dev/null || { cat "$TMP" >> "$OUT" 2>/dev/null; rm -f "$TMP"; }
sync 2>/dev/null || true

if [ "$VERBOSE" = "-v" ]; then echo "diag bundle written: $OUT"; fi
exit 0
