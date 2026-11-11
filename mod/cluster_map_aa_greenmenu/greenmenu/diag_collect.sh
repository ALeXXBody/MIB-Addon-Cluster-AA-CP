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

put() { echo "$1" >> "$TMP"; }
section() { echo "" >> "$TMP"; echo "== $1" >> "$TMP"; }

# _gal_env_lines CONFIG -- print one KEY=VALUE per line for the "envs" array
# of the "gal" child in the supervisor config.
#
# The v0.7.4 extractor only looked for a line that BEGINS with "envs", which
# this firmware's file does not have, so section 8 printed nothing at all on
# the car. This one reads the whole file into one buffer and walks to the
# gal child, then to its envs array, then prints each string that looks like
# an environment entry. It never prints anything from another child (the
# stock "mirrorlink" child is the reason the old section 5 could not tell an
# armed unit from a stock one).
_gal_env_lines()
{
    awk '
        { buf = buf $0 "\n" }
        END {
            s = index(buf, "\"gal\"")
            if (s == 0) exit 0
            rest = substr(buf, s)
            e = index(rest, "\"envs\"")
            if (e == 0) exit 0
            rest = substr(rest, e)
            a = index(rest, "[")
            if (a == 0) exit 0
            rest = substr(rest, a + 1)
            n = length(rest)
            i = 1
            while (i <= n) {
                c = substr(rest, i, 1)
                if (c == "]") break
                if (c != "\"") { i++; continue }
                j = i + 1; str = ""
                while (j <= n) {
                    c2 = substr(rest, j, 1)
                    if (c2 == "\\") { str = str substr(rest, j, 2); j += 2; continue }
                    if (c2 == "\"") break
                    str = str c2
                    j++
                }
                if (str ~ /^[A-Za-z_][A-Za-z0-9_]*=/) print str
                i = j + 1
            }
        }
    ' "$1" 2>/dev/null
}

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

# ---- 4b. the hook binary: card copy vs installed copy
# The install copies the .so from the card to /eso/lib/gal_dualscreen. A
# half-copied or stale unit binary is invisible unless both sides are
# measured, and the build string in the hook's own log (section 9,
# "event=init build=...") only identifies what is RUNNING, not what the
# card carries.
section "4b hook binary (card vs unit)"
_so_info()
{
    if [ ! -r "$1" ]; then echo "absent"; return; fi
    _sz=`ls -l "$1" 2>/dev/null | awk '{print $5}'`
    _h=""
    if command -v sha1sum >/dev/null 2>&1; then
        _h=`sha1sum "$1" 2>/dev/null | awk '{print $1}'`
        [ -n "$_h" ] && _h=" sha1=$_h"
    fi
    echo "size=${_sz:-?}$_h"
}
_SO_CARD="$PKG/libgal_hook.so"
_SO_UNIT=""
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    if [ -r "$_v/eso/lib/gal_dualscreen/libgal_hook.so" ]; then
        _SO_UNIT="$_v/eso/lib/gal_dualscreen/libgal_hook.so"; break
    fi
done
put "card: ${_SO_CARD:-none}"
put "      `_so_info "$_SO_CARD"`"
# v0.7.8: per-view table. The unit's gal resolves /eso on ITS OWN node, so a
# hook binary that landed on one node's app partition (the ladder's winner)
# can be invisible to gal on the other node -- the prime suspect for an
# armed hook that never starts. Name every view and where the .so is.
put "-- hook .so on every unit view (gal must find it on its own node) --"
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v" ] || continue
    put "  $_v/eso/lib/gal_dualscreen/libgal_hook.so"
    put "      `_so_info "$_v/eso/lib/gal_dualscreen/libgal_hook.so"`"
done

# ---- 5. arm state
section "5 arm state"
# Is the hook really inside the envs of the "gal" child? v0.7.4's check was
# a plain `grep LD_PRELOAD=` on the whole file, and this firmware's stock
# config already carries LD_PRELOAD for its own "mirrorlink" child -- so the
# bundle said YES on a completely unhooked unit. The envs are read out of
# the gal child only, and only its own LD_PRELOAD counts.
_GE=""
[ -r "$CFG" ] && _GE=`_gal_env_lines "$CFG"`
_PRELOAD="no"
if [ -n "$_GE" ]; then
    _PRELOAD_V=`echo "$_GE" | sed -n 's/^LD_PRELOAD=//p' | tail -1`
    case "$_PRELOAD_V" in
        "") _PRELOAD="no (the gal child has no LD_PRELOAD)" ;;
        *libgal_hook.so*) _PRELOAD="YES ($_PRELOAD_V)" ;;
        *) _PRELOAD="no (the gal child preloads $_PRELOAD_V, not the hook)" ;;
    esac
else
    _PRELOAD="unknown (could not read the gal child's envs from $CFG)"
fi
put "hook preloaded into gal (the gal child's own LD_PRELOAD): $_PRELOAD"
if [ -n "$_GE" ]; then
    _GE_N=`echo "$_GE" | awk 'NF { n++ } END { print n + 0 }'`
    _GE_GAL=`echo "$_GE" | awk '/^GAL_/ { n++ } END { print n + 0 }'`
    put "gal env entries: $_GE_N in total, $_GE_GAL of them GAL_*"
fi
put "engdefs/cluster-map.esd: `([ -d "$APPVIEW/eso/hmi/engdefs" ] && [ -f "$APPVIEW/eso/hmi/engdefs/cluster-map.esd" ] && echo present) || echo not-registered`"

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
section "7 installed settings (the file the hook actually loads)"
# The hook loads the FIRST file that exists among
#   /fs/sdb0, /fs/sda0, /eso/lib/gal_dualscreen (the unit copy), /tmp
# so a file at the card ROOT SHADOWS the unit copy. v0.7.4 dumped a fixed
# whitelist from the unit copy only: a card-root file was invisible, and so
# were the keys that decide the wheel (GAL_CLUSTER_REMOTE, GAL_REMOTE_TRACE),
# the cluster menu, hi-res and the IDR pump. Everything this add-on reads is
# GAL_*/CLUSTERMAP_*, so dump exactly that, from the file that wins, and say
# which file that is.
_ACTCONF=""
for _c in /fs/sdb0/gal_dualscreen.conf /fs/sda0/gal_dualscreen.conf \
          /net/mmx/fs/sdb0/gal_dualscreen.conf /net/mmx/fs/sda0/gal_dualscreen.conf \
          /net/mmx.mibhigh.net/fs/sdb0/gal_dualscreen.conf \
          /net/mmx.mibhigh.net/fs/sda0/gal_dualscreen.conf; do
    if [ -r "$_c" ]; then _ACTCONF="$_c"; break; fi
done
put "card-root file: ${_ACTCONF:-none}"
put "unit copy: $CONF"
if [ -n "$_ACTCONF" ]; then
    put "the hook loads: $_ACTCONF  (the card-root file wins over the unit copy)"
else
    put "the hook loads: $CONF  (no card-root file shadows it)"
fi
put "-- settings in the file the hook loads --"
if [ -r "${_ACTCONF:-$CONF}" ]; then
    grep -e "^GAL_" -e "^CLUSTERMAP_" "${_ACTCONF:-$CONF}" >> "$TMP" 2>/dev/null
else
    put "(not readable: ${_ACTCONF:-$CONF})"
fi
if [ -n "$_ACTCONF" ] && [ -r "$CONF" ]; then
    put "-- unit copy (SHADOWED by the card-root file: edits here do nothing) --"
    grep -e "^GAL_" -e "^CLUSTERMAP_" "$CONF" >> "$TMP" 2>/dev/null
fi

# ---- 8. supervisor config env keys
section "8 supervisor config (env KEY names only; no values)"
if [ -r "$CFG" ]; then
    put "config view: $CFG"
    if [ -n "$_GE" ]; then
        echo "$_GE" | sed -n 's/=.*//; s/^/  /p' >> "$TMP" 2>/dev/null
    else
        put "  (the gal child's envs could not be read; is this the stock config?)"
    fi
    put "persistent backup beside it: `([ -r "$CFG.gal-dualscreen.original" ] && echo present) || echo absent`"
    put "-- processes in this config (names only; gal's siblings) --"
    sed -n 's/^[[:space:]]*"\([A-Za-z0-9_]*\)"[[:space:]]*:[[:space:]]*{.*/  \1/p' "$CFG" >> "$TMP" 2>/dev/null
else
    put "(supervisor config not reachable from this view: $CFG)"
fi

# ---- 9. hook log tail
section "9 hook log tail (last 120 lines)"
# The hook's default log is <card>/logs/gal_dualscreen.log (the card root),
# with /tmp/gal_dualscreen.log as the RAM fallback -- plus whatever
# GAL_HOOK_LOG names. v0.7.4 only checked the payload folder and /tmp, so a
# real log written on the card was reported as "no hook log", which sent the
# whole wheel round chasing a hook that had in fact been running.
LOG=""
for _c in /fs/sdb0/logs/gal_dualscreen.log /fs/sda0/logs/gal_dualscreen.log \
          /net/mmx/fs/sdb0/logs/gal_dualscreen.log /net/mmx/fs/sda0/logs/gal_dualscreen.log \
          "$PKG/logs/gal_dualscreen.log" /tmp/gal_dualscreen.log; do
    [ -r "$_c" ] && { LOG="$_c"; break; }
done
_HOOKLOG_ENV=`echo "$_GE" | sed -n 's/^GAL_HOOK_LOG=//p' | tail -1`
if [ -n "$_HOOKLOG_ENV" ]; then
    put "GAL_HOOK_LOG (supervisor env): $_HOOKLOG_ENV"
    [ -z "$LOG" ] && [ -r "$_HOOKLOG_ENV" ] && LOG="$_HOOKLOG_ENV"
fi
if [ -n "$LOG" ]; then
    put "source: $LOG"
    put "VERDICT: the hook HAS run on this unit (its log exists)."
    put "-- its start line (init) --"
    sed -n '/event=init/p' "$LOG" 2>/dev/null | head -3 >> "$TMP"
    put "-- first 12 lines --"
    head -12 "$LOG" >> "$TMP" 2>/dev/null
    put "-- last 120 lines --"
    tail -120 "$LOG" >> "$TMP" 2>/dev/null
else
    put "(no hook log at the card root logs/, the payload folder, /tmp, or GAL_HOOK_LOG)"
    # The owner asked for the diag to ANSWER, not just list. /tmp is RAM and
    # is wiped at every boot, so the install-home marker tells us whether
    # THIS boot has already seen an install run: a missing marker after a
    # reboot means the boot is fresh -- and the hook still never started.
    _LASTPATHS="`([ -r /tmp/clustermap_last_paths ] && echo present) || echo absent`"
    put "install-home marker (/tmp/clustermap_last_paths): $_LASTPATHS"
    case "$_LASTPATHS" in
        present) put "VERDICT: the last install ran in THIS boot session -- the unit has"
                 put "NOT been rebooted since. Reboot now (power button ~10 s), connect the"
                 put "phone, start Android Auto, then Save logs again." ;;
        absent)  case "$_PRELOAD" in
                     YES*) put "VERDICT: this boot is fresh (the marker above is wiped at every"
                           put "boot) and the hook STILL never started. Prime suspect: gal cannot"
                           put "resolve the preload path on its own node -- section 4b above shows"
                           put "which unit views carry the hook binary and which do not. Send this"
                           put "file." ;;
                     *) put "VERDICT: the hook is not armed; run /mod/custom.sh once, then reboot." ;;
                 esac ;;
    esac
fi
put "-- log folders --"
for _d in /fs/sdb0/logs /fs/sda0/logs "$PKG/logs" /tmp; do
    [ -d "$_d" ] || continue
    put "$_d:"
    ls "$_d" 2>/dev/null | head -20 | sed 's/^/  /' >> "$TMP" 2>/dev/null
done

# ---- 9b. the hook's live runtime files
# These are what the switches arm (and what the hook reads per gesture), so
# their presence and contents decide every "the switch says ON but nothing
# happens" report. /tmp/gal_inject is the key-injection probe, listed here
# because an owner who used it needs it in the bundle.
section "9b hook runtime files (/tmp, read live by the hook)"
for _f in /tmp/gal_remote /tmp/gal_remote_trace /tmp/gal_cluster_menu /tmp/gal_hires \
          /tmp/gal_idr_pump /tmp/gal_uiconfig /tmp/stream-player.menu \
          /tmp/stream-player.zoom /tmp/stream-player.navstrip \
          /tmp/gal_kombi_ready /tmp/gal_inject; do
    if [ -r "$_f" ]; then
        put "$_f = `sed -n 1p "$_f" 2>/dev/null`"
    else
        put "$_f = (absent)"
    fi
done

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
