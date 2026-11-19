#!/bin/sh
# menu_states.sh - feature states for the main menu and Status.
#
#   menu_states.sh [conf_file]      one line: the main menu's States row.
#   menu_states.sh -v [conf_file]   the Status block: every family with
#                                   its setting and when it takes effect.
#
# Prints e.g. "States: remote, wheel, zoom 1.15" or "States: stock (all
# off)". Reads the installed settings copy (first readable app-view
# spelling, or the file named on the command line) plus the hook's live
# /tmp flags -- never remounts, never writes, never fails (exit 0,
# "States: --" when nothing is readable). Read-only by design: the
# installer (custom.sh, baking the screen), the menu refresh path
# (menus.sh run_quiet, after every press) and Status all call it.
HERE=`dirname "$0"` || HERE=""
RT="${GAL_RUNTIME_DIR:-/tmp}"

VERBOSE=0
if [ "$1" = "-v" ]; then VERBOSE=1; shift; fi

CONF="$1"
if [ -z "$CONF" ]; then
    for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
        if [ -r "$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf" ]; then
            CONF="$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf"
            break
        fi
    done
fi

# conf key, last value wins (same rule the switches use when they read).
ckey() {
    if [ -r "$CONF" ]; then
        sed -n "s/^$1=//p" "$CONF" 2>/dev/null | tail -1
    fi
}
# live /tmp flag, first line.
lkey() {
    if [ -r "$RT/$1" ]; then
        sed -n '1p' "$RT/$1" 2>/dev/null
    fi
}

S=""
add() {
    if [ -z "$S" ]; then S="$1"; else S="$S, $1"; fi
}

# THE ROW (one line for the main menu) is CONFIGURATION ONLY, never live
# state: /tmp wipes on every reboot and ports only exist after one, so any
# live-derived word would go stale until the next press -- the exact lie
# the owner caught. Conf never changes except through a press, and every
# press refreshes the row, so this is always true. Live truth (ports,
# pids, running map) belongs to Status -v below, which is computed fresh
# on every press.
if [ -r "$CONF" ]; then
    RC=`ckey GAL_CLUSTER_REMOTE` || RC=""
    [ "$RC" = 1 ] && add "remote"
    WC=`ckey GAL_WHEEL_LISTEN` || WC=""
    [ "$WC" != 0 ] && add "wheel"
    ZE=`ckey GAL_PLAYER_ZOOM_E4` || ZE=""
    case "$ZE" in
        11500) add "zoom 1.15" ;;
        13500) add "zoom 1.35" ;;
    esac
    NC=`ckey GAL_NAV_INFO_STRIP` || NC=""
    [ "$NC" = 1 ] && add "strip"
    IC=`ckey GAL_SECONDARY_INSETS` || IC=""
    case "$IC" in ''|'40,40,127,127') ;; *) add "card" ;; esac
    PC=`ckey GAL_IDR_PUMP` || PC=""
    case "$PC" in ''|0) ;; *) add "pump" ;; esac
    HC=`ckey GAL_SECONDARY_HIRESEN` || HC=""
    [ "$HC" = 1 ] && add "hires"
    CMC=`ckey GAL_CLUSTER_MENU` || CMC=""
    [ "$CMC" = 1 ] && add "clustermenu"
    TTC=`ckey GAL_REMOTE_TRACE` || TTC=""
    [ "$TTC" = 1 ] && add "tap trace"
    KMC=`ckey GAL_KEEP_MAP` || KMC=""
    [ "$KMC" = phone ] && add "keep map"
    ECC=`ckey GAL_SECONDARY_UI_CONFIG_HEX` || ECC=""
    [ -n "$ECC" ] && add "eta $ECC"
fi

# Live values for the Status block below (freshly computed per press).
R=`lkey gal_remote` || R=""
if [ -z "$R" ]; then
    R=`ckey GAL_CLUSTER_REMOTE` || R=""
fi

# Live values for the Status block below (freshly computed per press).
# The one-liner above uses conf only; these add nothing to $S.
W=""
PORTS_LIVE="unknown"
[ -r "$CONF" ] && W=`ckey GAL_WHEEL_LISTEN` || W=""
if [ -r "$CONF" ] && [ "$W" != 0 ]; then
    if command -v netstat >/dev/null 2>&1; then
        if netstat -an 2>/dev/null | grep -qE "[:.]1798 |[:.]20991 "; then
            PORTS_LIVE=1
        else
            PORTS_LIVE=0
        fi
    fi
fi

# zoom: the live file first (the player polls it), else the conf value.
Z=`lkey stream-player.zoom` || Z=""
ZLIVE=0
[ -n "$Z" ] && ZLIVE=1
if [ -z "$Z" ]; then
    Z=`ckey GAL_PLAYER_ZOOM_E4` || Z=""
    case "$Z" in
        11500) Z="1.15" ;;
        13500) Z="1.35" ;;
        10000|'') Z="" ;;
        *) Z="" ;;
    esac
fi

# turn strip: live file first (the running player polls it), persisted
# key after a reboot wiped /tmp. Adds nothing to $S (row is conf-only).
N=`lkey stream-player.navstrip` || N=""
NLIVE=0
[ -n "$N" ] && NLIVE=1
if [ -z "$N" ]; then
    N=`ckey GAL_NAV_INFO_STRIP` || N=""
fi

# card clear: live uiconfig file (written per press/cycle). The row uses
# the persisted insets instead; this adds nothing to $S.
UIC_ARMED=0
[ -r "$RT/gal_uiconfig" ] && UIC_ARMED=1

# sharpness pump: live level first, persisted key after a reboot.
P=`lkey gal_idr_pump` || P=""
PLIVE=0
[ -n "$P" ] && PLIVE=1
if [ -z "$P" ]; then
    P=`ckey GAL_IDR_PUMP` || P=""
fi

# hi-res: live flag or conf key. Adds nothing to $S (row is conf-only).
H=`lkey gal_hires` || H=""
[ "$H" = 1 ] && HLIVE=1 || HLIVE=0
HE=`ckey GAL_SECONDARY_HIRESEN` || HE=""

# cluster menu + AA tap trace: same live-then-conf shape as remote.
CM=`lkey gal_cluster_menu` || CM=""
if [ -z "$CM" ]; then
    CM=`ckey GAL_CLUSTER_MENU` || CM=""
fi
TT=`lkey gal_remote_trace` || TT=""
if [ -z "$TT" ]; then
    TT=`ckey GAL_REMOTE_TRACE` || TT=""
fi
# AA-path liveness: the remote/menu/tap trio feeds EXCLUSIVELY on
# outbound 0x8001 InputReports (video_sink_hook.c: the gesture parser is
# called only for id == 0x8001). This unit never emits one (8 sessions,
# zero sightings), so a switch left ON there is armed but idle. Definitive
# only when a hook log exists and carries no 0x8001 line at all.
AA_IDLE=0
HOOKLOG_SEEN=0
_HL="${GAL_HOOK_LOG:-/tmp/gal_dualscreen.log}"
for _hl in "$_HL" "$_HL.prev"; do
    [ -r "$_hl" ] || continue
    HOOKLOG_SEEN=1
    if grep -q "0x8001" "$_hl" 2>/dev/null; then AA_IDLE=0; break; fi
    AA_IDLE=1
done
unset _hl _HL
# No hook log at all (gal never ran: no phone session this boot) is not
# "live" and not "idle" -- it is unknown. Say exactly that.
# keep map + ETA card: settings keys only (no live files).
KM=`ckey GAL_KEEP_MAP` || KM=""
EC=`ckey GAL_SECONDARY_UI_CONFIG_HEX` || EC=""

if [ "$VERBOSE" = 1 ]; then
    # Compact block for Status: every family, setting, and when it lands.
    # Timings verified against the hook sources (per-gesture fopen for
    # remote/menu/tap, 1 Hz poll for pump and the player files, per
    # session for hi-res, gal start for the HEX card, boot ports live
    # for the wheel).
    echo "Features (setting -> when it lands):"
    if [ "$R" = 1 ]; then
        if [ "$HOOKLOG_SEEN" = 0 ]; then echo "  Cluster remote: ON (no session yet)";
        elif [ "$AA_IDLE" = 1 ]; then echo "  Cluster remote: ON (idle: no wheel reports)";
        else echo "  Cluster remote: ON (live)"; fi
    else
        echo "  Cluster remote: off"
    fi
    if [ ! -r "$CONF" ]; then
        echo "  Wheel control: unknown (no settings readable)"
    elif [ "$W" = 0 ]; then
        echo "  Wheel control: OFF"
    elif [ "$PORTS_LIVE" = 1 ]; then
        echo "  Wheel control: ON (live)"
    else
        echo "  Wheel control: ON (needs 1 reboot)"
    fi
    if [ -n "$Z" ]; then
        if [ "$ZLIVE" = 1 ]; then echo "  Zoom: $Z (live)"; else echo "  Zoom: $Z (next session)"; fi
    else
        echo "  Zoom: off"
    fi
    if [ "$N" = 1 ]; then
        if [ "$NLIVE" = 1 ]; then echo "  Turn strip: ON (live)"; else echo "  Turn strip: ON (next session)"; fi
    else
        echo "  Turn strip: off"
    fi
    ICV=`ckey GAL_SECONDARY_INSETS` || ICV=""
    if [ "$UIC_ARMED" = 1 ]; then
        echo "  Card clear: armed (live)"
    else
        case "$ICV" in ''|'40,40,127,127') echo "  Card clear: off" ;; *) echo "  Card clear: armed (next session)" ;; esac
    fi
    if [ "$CM" = 1 ]; then
        if [ "$HOOKLOG_SEEN" = 0 ]; then echo "  Cluster menu: ON (no session yet)";
        elif [ "$AA_IDLE" = 1 ]; then echo "  Cluster menu: ON (idle: no wheel reports)";
        else echo "  Cluster menu: ON (live)"; fi
    else
        echo "  Cluster menu: off"
    fi
    if [ "$TT" = 1 ]; then
        if [ "$HOOKLOG_SEEN" = 0 ]; then echo "  AA tap trace: ON (no session yet)";
        elif [ "$AA_IDLE" = 1 ]; then echo "  AA tap trace: ON (idle: no wheel reports)";
        else echo "  AA tap trace: ON (live)"; fi
    else
        echo "  AA tap trace: off"
    fi
    if [ "$H" = 1 ] || [ "$HE" = 1 ]; then echo "  Hi-res: ON (next session)"; else echo "  Hi-res: off"; fi
    case "$P" in
        ''|0) echo "  Pump: off" ;;
        *) if [ "$PLIVE" = 1 ]; then echo "  Pump: ${P}s (live)"; else echo "  Pump: ${P}s (next session)"; fi ;;
    esac
    case "$KM" in phone) echo "  Keep map: phone (next session)" ;; *) echo "  Keep map: off" ;; esac
    if [ -n "$EC" ]; then echo "  ETA card: $EC (next start)"; else echo "  ETA card: off"; fi
    exit 0
fi

if [ -z "$S" ]; then
    echo "States: stock (all off)"
else
    echo "States: $S"
fi
exit 0
