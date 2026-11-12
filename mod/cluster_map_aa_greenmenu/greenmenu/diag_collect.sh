#!/bin/sh
# diag_collect.sh — writes ONE bundle file:
#   /tmp/clustermap_diag/diag.txt        (unit RAM, always, authoritative)
#   <payload>/diag.txt                   (best-effort copy on the card)
#
# THE OWNER ASKED FOR THIS FILE TO CARRY EVERYTHING NEEDED TO DIAGNOSE.
# It does. No truncation of the hook log's decisive events; every process,
# every socket, every binary, every runtime file, every config value.
#
# Console behaviour: SILENT unless asked (diag_collect.sh -v). The bundle is
# the product; the GEM console stays readable.
#
# Sections and what they answer:
#   1 unit/train            - which firmware, is its train profile known
#   2 payload integrity     - unit-state + what the card actually carries
#   3 card views            - where the card sits, mount-table reality
#   4 unit view ladder      - which partition spelling the console can reach
#   4b hook binary          - card copy vs installed copy, per view
#   5 arm state             - hook armed / GEM screen registered or not
#   6 engdefs listing       - GEM diagnostics WITHOUT touching those files
#   6b live screen paths    - does every script the screen names exist?
#   7 installed settings    - window, dpi, insets, aspect, zoom, full-frame
#   8 supervisor config     - which view serves it, env KEY+VALUES, processes
#   9 hook log              - FULL log: init, all event= lines, tail
#   9b runtime files        - every /tmp file the hook reads live
#   9c map renderer         - is stream-player running? processes + logs
#   9d socket state         - is the hook's TCP port listening?
#   9e gal process env      - the gal process's ACTUAL runtime environment
#  10 install paths         - where the install wrote backups/logs
#  11 last run summary     - the filtered result lines of the recent run
#  12 full run log          - the entire last operation

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

# ---- 4b. the hook binary: card copy vs installed copy, per view
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
put "card: ${_SO_CARD:-none}"
put "      `_so_info "$_SO_CARD"`"
put "-- hook .so on every unit view (gal must find it on its own node) --"
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v" ] || continue
    put "  $_v/eso/lib/gal_dualscreen/libgal_hook.so"
    put "      `_so_info "$_v/eso/lib/gal_dualscreen/libgal_hook.so"`"
done
# stream-player binary on every view (the map renderer)
put "-- stream-player binary on every unit view --"
for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
    [ -d "$_v" ] || continue
    for _p in "$_v/eso/bin/stream-player" "$_v/navigation/stream-player"; do
        if [ -f "$_p" ]; then
            put "  $_p  size=`ls -l "$_p" 2>/dev/null | awk '{print $5}'`  exec=`([ -x "$_p" ] && echo yes) || echo no`"
        fi
    done
done

# ---- 5. arm state
section "5 arm state"
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
_EDEFSLIVE=""
for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
    if [ -f "$_v/eso/hmi/engdefs/cluster-map.esd" ]; then
        _EDEFSLIVE="$_v/eso/hmi/engdefs/cluster-map.esd"
        ls "$_v/eso/hmi/engdefs" >> "$TMP" 2>/dev/null
        break
    fi
done
[ -n "$_EDEFSLIVE" ] || put "(engdefs cluster-map.esd not reachable from this console view)"

# 6b. THE "Script not found" CHECK
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

# ---- 9. hook log (FULL capture — the owner asked for everything)
section "9 hook log"
# The hook's default log is <card>/logs/gal_dualscreen.log (the card root),
# with /tmp/gal_dualscreen.log as the RAM fallback -- plus whatever
# GAL_HOOK_LOG names. Capture EVERYTHING, not just a tail: the decisive
# events (player.spawn, aap.playback, aap.video_focus, focus.healthy) live
# in the MIDDLE of the log, not at the head or tail.
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
    put "size: `ls -l "$LOG" 2>/dev/null | awk '{print $5}'` bytes"
    put "VERDICT: the hook HAS run on this unit (its log exists)."
    put "-- its start line (init) --"
    sed -n '/event=init/p' "$LOG" 2>/dev/null | head -5 >> "$TMP"
    put "-- key mid-log events (player, playback, focus, sinks, stream) --"
    grep -E "event=(player\.|aap\.playback|aap\.video_focus|secondary\.video_config|primary\.register|service\.class|impl_at_sink|stream\.mode|stream\.open|stream\.idr|focus\.healthy|fix\.config|aap\.frame$)" "$LOG" 2>/dev/null >> "$TMP"
    put "-- first 20 lines --"
    head -20 "$LOG" >> "$TMP" 2>/dev/null
    put "-- full log (all lines) --"
    cat "$LOG" >> "$TMP" 2>/dev/null
else
    put "(no hook log at the card root logs/, the payload folder, /tmp, or GAL_HOOK_LOG)"
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

# ---- 9c. is the map renderer (stream-player) actually running?
section "9c map renderer (stream-player process)"
if command -v pidin >/dev/null 2>&1; then
    put "stream-player instances: `pidin info 2>/dev/null | grep -c stream-player`"
    put "gal instances: `pidin info 2>/dev/null | grep -c ' gal '`"
    put "matching lines:"
    pidin info 2>/dev/null | grep -iE "stream-player| gal " >> "$TMP" 2>/dev/null
else
    put "(pidin not available on this unit)"
fi
put "stream-player binary: `([ -f /mnt/app/navigation/stream-player ] && echo present) || echo absent`"
put "stream-player log on the card: `([ -r /fs/sda0/logs/stream-player.log ] && echo present) || echo absent`"
put "stream-player log in /tmp: `([ -r /tmp/stream-player.log ] && echo present) || echo absent`"
if [ -r /tmp/stream-player.log ]; then
    put "-- stream-player log (all lines) --"
    cat /tmp/stream-player.log >> "$TMP" 2>/dev/null
fi

# The gal process's ACTUAL runtime environment (not the config file's
# intent). If LD_PRELOAD is missing here, the hook never loaded even though
# the config file carries it -- the config is not the one gal reads.
section "9e gal process runtime environment"
if command -v pidin >/dev/null 2>&1; then
    _GALPID=`pidin info 2>/dev/null | grep ' gal ' | head -1 | awk '{print $1}'`
    if [ -n "$_GALPID" ]; then
        put "gal pid: $_GALPID"
        put "gal process line:"
        pidin info 2>/dev/null | grep ' gal ' | head -1 >> "$TMP" 2>/dev/null
        put "gal environment (pidin -p $_GALPID env):"
        pidin -p "$_GALPID" env 2>/dev/null >> "$TMP" 2>/dev/null ||             put "(pidin -p env not supported on this unit)"
    else
        put "no gal process found (gal has not started yet?)"
    fi
    put "-- ALL processes (pidin info full) --"
    pidin info 2>/dev/null >> "$TMP" 2>/dev/null
else
    put "(pidin not available on this unit)"
fi
# ---- 9d. socket state (is the hook's TCP port listening?)
section "9d socket state (hook TCP port)"
if command -v netstat >/dev/null 2>&1; then
    put "-- netstat (port 12346 / stream) --"
    netstat -an 2>/dev/null | grep -iE "12346|stream|LISTEN" >> "$TMP" 2>/dev/null
elif [ -r /proc/net/tcp ]; then
    put "-- /proc/net/tcp (port 12346 = 0x303A) --"
    grep -i "303A" /proc/net/tcp >> "$TMP" 2>/dev/null || put "(port 12346 not in /proc/net/tcp)"
else
    put "(no netstat or /proc/net/tcp on this unit)"
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

# ---- 12. full log of the last operation (the pages the console used to)
section "12 full log of the last operation (capped at 400 lines)"
if [ "$MODE" = append-run ] && [ -r "$RUNLOG" ] && [ -n "$RUNLOG" ]; then
    head -400 "$RUNLOG" >> "$TMP" 2>/dev/null
fi

# ---- deliver ----------------------------------------------------------------
[ -r "$OUT" ] && cat "$OUT" > "$OUT.prev" 2>/dev/null
[ -s "$TMP" ] || echo "(empty bundle)" >> "$TMP"
cat "$TMP" > "$OUT" 2>/dev/null || cp "$TMP" "$OUT" 2>/dev/null
rm -f "$TMP" 2>/dev/null
echo "$OUT" > /tmp/clustermap_diag/LAST_PATH 2>/dev/null

# ONE copy onto the card, ANYWHERE it can be verified to land.
CARDOUT=""; _WAS_REMOUNTED="0"
if [ -d "$PKG" ]; then
    for _root in "$VOLUME" /fs/sda0 /fs/sdb0 /fs/sda1 /net/mmx/fs/sda0 \
                 /net/mmx/fs/sdb0 /net/mmx.mibhigh.net/fs/sda0 \
                 /net/mmx.mibhigh.net/fs/sdb0; do
        [ -n "$_root" ] && [ -d "$_root" ] || continue
        _d=""
        for _rel in mod/cluster_aa mod/cluster_map_aa_greenmenu ClusterMap \
                    cluster_map_aa_greenmenu mod/ClusterMap; do
            if [ -f "$_root/$_rel/enable_hook.sh" ]; then
                _d="$_root/$_rel"; break
            fi
        done
        for _h in "$_d" "$_root"; do
            [ -n "$_h" ] && [ -d "$_h" ] || continue
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
