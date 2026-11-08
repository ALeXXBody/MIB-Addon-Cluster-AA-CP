#!/bin/sh
# diag_collect.sh — writes ONE bundle file:
#   /tmp/clustermap_diag/diag.txt        (unit RAM, always, authoritative)
#   <payload>/diag.txt                   (best-effort copy on the card)
# The owner sends that single file; everything needed to diagnose an add-on
# problem or tune the map is inside it. It is written by every install,
# uninstall and settings run (see custom.sh / menus.sh), and can also run
# directly from M.I.B.'s own "Run custom script" as
#   mod/cluster_aa/greenmenu/diag_collect.sh
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

# Arguments, in any order (callers use both "[-v]" and "[append-run] [log]"):
#   append-run   append the 11/12 sections (the curated + full run log)
#   <log file>   the log to append
#   -v           narrate the delivery on stdout (the GEM console)
MODE=""; RUNLOG=""; VERBOSE=0
for _a in "$@"; do
    case "$_a" in
        -v)         VERBOSE=1 ;;
        append-run) MODE=append-run ;;
        *)          [ -f "$_a" ] && RUNLOG="$_a" ;;
    esac
done

# Portable helpers (the unit shell again: no printf/tr/diff bashisms).
# RULE — THE CARD IS NEVER WRITTEN during normal operation. The bundle is
# therefore always built on the unit's RAM first (/tmp, guaranteed), and the
# card is only given a best-effort COPY at the very end, once, for the
# owner's convenience. A card that refuses the copy does not fail anything:
# the /tmp file remains the source of truth and the console names it.
mkdir -p /tmp/clustermap_diag 2>/dev/null
TMP=/tmp/clustermap_diag/diag.tmp.$$
( : > "$TMP" ) 2>/dev/null || { echo "diag_collect: cannot write /tmp/clustermap_diag" >&2; exit 1; }
OUT=/tmp/clustermap_diag/diag.txt

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
[ -r "$PKG/VERSION" ] && put "payload version: `cat "$PKG/VERSION"`"

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
# the LIVE registration can live under ANY app view spelling (the install
# writes through the alias that accepted its probe); search everywhere.
_EDEFSLIVE=""
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
    if [ -f "$_v/eso/hmi/engdefs/cluster-map.esd" ]; then
        _EDEFSLIVE="$_v/eso/hmi/engdefs/cluster-map.esd"
        ls "$_v/eso/hmi/engdefs" >> "$TMP" 2>/dev/null
        break
    fi
done
[ -n "$_EDEFSLIVE" ] || put "(engdefs cluster-map.esd not reachable from this console view)"

# 6b. THE "Script not found" CHECK: read the LIVE screen file's script
# values and tell, per entry, whether that path exists. This is the exact
# assertion the GEM makes when a button is pressed; the diag therefore
# answers a dead menu on its own.
section "6b live screen script paths (the GEM's own resolution)"
_live="${_EDEFSLIVE:-$APPVIEW/eso/hmi/engdefs/cluster-map.esd}"
if [ -f "$_live" ]; then
    sed -n 's,^.*"\(/net/[^"]*\.sh\)[^"]*".*,\1,p' "$_live" | while IFS= read -r _sp; do
        _sp=${_sp%% *}
        case "$_sp" in */esd/scripts/*) continue ;; esac
        if [ -f "$_sp" ]; then
            echo "  ok        $_sp"
        else
            echo "  MISSING   $_sp"
        fi
    done >> "$TMP" 2>/dev/null
else
    put "(no live screen file to check)"
fi

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
if [ "$MODE" = append-run ] && [ -r "$RUNLOG" ] && [ -n "$RUNLOG" ]; then
    "$HERE/console_summary.sh" "$RUNLOG" >> "$TMP" 2>/dev/null
fi
# (the caller appends after us)

# ---- 12. full log of the last operation (the pages the console used to)
section "12 full log of the last operation (capped at 400 lines)"
if [ "$MODE" = append-run ] && [ -r "$RUNLOG" ] && [ -n "$RUNLOG" ]; then
    head -400 "$RUNLOG" >> "$TMP" 2>/dev/null
fi

# ---- deliver ----------------------------------------------------------------
# The guaranteed home is on the unit (/tmp). Keep the newest bundle plus one
# previous copy (a run that went bad must not destroy the last good evidence).
[ -r "$OUT" ] && cat "$OUT" > "$OUT.prev" 2>/dev/null
[ -s "$TMP" ] || echo "(empty bundle)" >> "$TMP"
cat "$TMP" > "$OUT" 2>/dev/null || cp "$TMP" "$OUT" 2>/dev/null
rm -f "$TMP" 2>/dev/null
echo "$OUT" > /tmp/clustermap_diag/LAST_PATH 2>/dev/null

# ONE copy onto the card, ANYWHERE it can be verified to land.
#
# Hard lessons baked in here:
#  1. no silent failure: the outcome (success path OR refusal) is narrated
#     on the console; the tuning facts print when the card refuses so a
#     screen photo replaces the file for a tuning round.
#  2. no cp: shell redirection + checksum verify - the unit shells carry
#     their own tool set, and a missing cp was a silent-failure mode.
#  3. every spelling and every home is probed: the payload folder under
#     each card view (/fs/sda0, /net/..., FQDN ~) AND, when all those
#     refuse, the card ROOT of the spelling that can still be written.
#     A file is only claimed after the bytes are confirmed back.
CARDOUT=""; _WAS_REMOUNTED="0"
if [ -d "$PKG" ]; then
    for _root in "$VOLUME" /fs/sda0 /fs/sdb0 /fs/sda1 /net/mmx/fs/sda0 \
                 /net/mmx/fs/sdb0 /net/mmx.mibhigh.net/fs/sda0 \
                 /net/mmx.mibhigh.net/fs/sdb0; do
        [ -n "$_root" ] && [ -d "$_root" ] || continue
        # the payload layout under this spelling (same list find_card uses;
        # no string surgery, so this works in every sh the unit ships)
        _d=""
        for _rel in mod/cluster_aa mod/cluster_map_aa_greenmenu ClusterMap \
                    cluster_map_aa_greenmenu mod/ClusterMap; do
            if [ -f "$_root/$_rel/enable_hook.sh" ]; then
                _d="$_root/$_rel"; break
            fi
        done
        # homes to try, first choice first: payload folder, then card root
        # (subshell probes: dash ABORTS the whole shell when a special
        # builtin's redirection fails - that killed the run in v0.4.22)
        for _h in "$_d" "$_root"; do
            [ -n "$_h" ] && [ -d "$_h" ] || continue
            # UNIT FACT (the owner's): the unit mounts the SD card READ-ONLY
            # at boot. A write is only possible after ONE explicit remount
            # (`mount -uw`); after the verified copy the card goes back
            # read-only, so the RW window is exactly this one copy.
            _remounted="0"
            if ! ( : > "$_h/.clustermap_card_probe" ) 2>/dev/null; then
                mount -uw "$_root" 2>/dev/null
                _remounted="1"; _WAS_REMOUNTED="1"
                ( : > "$_h/.clustermap_card_probe" ) 2>/dev/null || continue
            fi
            rm -f "$_h/.clustermap_card_probe" 2>/dev/null
            if cat "$OUT" > "$_h/diag.txt" 2>/dev/null && \
               [ -s "$_h/diag.txt" ]; then
                _ok=1
                if command -v cksum >/dev/null 2>&1; then
                    _a=`cksum "$OUT" 2>/dev/null | awk '{print $1" "$2}'`
                    _b=`cksum "$_h/diag.txt" 2>/dev/null | awk '{print $1" "$2}'`
                    [ -n "$_a" ] && [ "$_a" = "$_b" ] || _ok=0
                fi
                if [ "$_ok" = 1 ]; then
                    CARDOUT="$_h/diag.txt"
                    [ -r "$OUT.prev" ] && \
                        cat "$OUT.prev" > "$_h/diag.txt.prev" 2>/dev/null
                    sync 2>/dev/null || true
                    [ "$_remounted" = 1 ] && mount -ur "$_root" 2>/dev/null
                    break 2
                fi
                rm -f "$_h/diag.txt" 2>/dev/null
            fi
        done
    done
fi

# ---- the fine-tune facts (printed when the card refused the copy) -----------
facts() {
    for _k in GAL_PLAYER_WINDOW GAL_SECONDARY_DPI GAL_SECONDARY_INSETS \
              GAL_SECONDARY_MARGINS GAL_PLAYER_ZOOM_E4 CLUSTERMAP_FULL_FRAME; do
        _l=`grep "^$_k" "$CONF" 2>/dev/null | head -1`
        [ -n "$_l" ] && echo "  $_l"
    done
}

if [ "$VERBOSE" = 1 ]; then
    echo "diag bundle: $OUT"
    if [ "$_WAS_REMOUNTED" = 1 ]; then
        echo "card note:    the card was read-only; remounted rw for this copy"
    fi
    if [ -n "$CARDOUT" ]; then
        echo "card copy:   $CARDOUT"
    else
        echo "card copy:   NOT WRITTEN - the card is read-only to the unit."
        if [ "$_WAS_REMOUNTED" = 1 ]; then
            echo "             even after 'mount -uw' no card view took the write."
        fi
        echo "             On a PC: eject the card safely (not just pull it),"
        echo "             then GEM -> ClusterMap -> \"10/11. Save logs\"."
        echo "             If you cannot, photograph these lines instead:"
        facts
    fi
fi
exit 0
