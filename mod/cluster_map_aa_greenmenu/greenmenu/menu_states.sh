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

# remote: the hook reads the live flag at every gesture; after a reboot
# /tmp is wiped, so fall back to the persisted settings key.
R=`lkey gal_remote` || R=""
if [ -z "$R" ]; then
    R=`ckey GAL_CLUSTER_REMOTE` || R=""
fi
[ "$R" = 1 ] && add "remote"

# wheel: enabled unless the conf explicitly opts out; needs the HMI
# tracer ports, so a silent port pair earns the reboot reminder. Without
# any readable conf there is nothing to report (never assume ON).
W=""
PORTS_LIVE="unknown"
[ -r "$CONF" ] && W=`ckey GAL_WHEEL_LISTEN` || W=""
if [ -r "$CONF" ] && [ "$W" != 0 ]; then
    if command -v netstat >/dev/null 2>&1; then
        if netstat -an 2>/dev/null | grep -qE "[:.]1798 |[:.]20991 "; then
            PORTS_LIVE=1
            add "wheel"
        else
            PORTS_LIVE=0
            add "wheel (reboot once)"
        fi
    else
        add "wheel"
    fi
fi

# zoom: the live file wins (the player polls it); else the conf E4 value.
Z=`lkey stream-player.zoom` || Z=""
if [ -n "$Z" ]; then
    add "zoom $Z"
else
    ZE=`ckey GAL_PLAYER_ZOOM_E4` || ZE=""
    case "$ZE" in
        11500) add "zoom 1.15" ;;
        13500) add "zoom 1.35" ;;
    esac
fi

# turn strip: live file first (the running player polls it), persisted
# key after a reboot wiped /tmp.
N=`lkey stream-player.navstrip` || N=""
if [ -z "$N" ]; then
    N=`ckey GAL_NAV_INFO_STRIP` || N=""
fi
[ "$N" = 1 ] && add "strip"

# card clear: any armed uiconfig (absent = full window, nothing to show).
if [ -r "$RT/gal_uiconfig" ]; then add "card"; fi

# sharpness pump: live level first, persisted key after a reboot.
P=`lkey gal_idr_pump` || P=""
if [ -z "$P" ]; then
    P=`ckey GAL_IDR_PUMP` || P=""
fi
case "$P" in ''|0) ;; *) add "pump" ;; esac

# hi-res: live flag or conf key.
H=`lkey gal_hires` || H=""
[ "$H" = 1 ] && add "hires"
if [ "$H" != 1 ]; then
    HE=`ckey GAL_SECONDARY_HIRESEN` || HE=""
    [ "$HE" = 1 ] && add "hires"
fi

# cluster menu + AA tap trace: same live-then-conf shape as remote.
CM=`lkey gal_cluster_menu` || CM=""
if [ -z "$CM" ]; then
    CM=`ckey GAL_CLUSTER_MENU` || CM=""
fi
TT=`lkey gal_remote_trace` || TT=""
if [ -z "$TT" ]; then
    TT=`ckey GAL_REMOTE_TRACE` || TT=""
fi
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
    if [ "$R" = 1 ]; then echo "  Cluster remote: ON (live)"; else echo "  Cluster remote: off"; fi
    if [ ! -r "$CONF" ]; then
        echo "  Wheel control: unknown (no settings readable)"
    elif [ "$W" = 0 ]; then
        echo "  Wheel control: OFF"
    elif [ "$PORTS_LIVE" = 1 ]; then
        echo "  Wheel control: ON (live)"
    else
        echo "  Wheel control: ON (needs 1 reboot)"
    fi
    if [ -n "$Z" ]; then echo "  Zoom: $Z (live)"; else echo "  Zoom: off"; fi
    if [ "$N" = 1 ]; then echo "  Turn strip: ON (live)"; else echo "  Turn strip: off"; fi
    if [ -r "$RT/gal_uiconfig" ]; then echo "  Card clear: armed (live)"; else echo "  Card clear: off"; fi
    if [ "$CM" = 1 ]; then echo "  Cluster menu: ON (live)"; else echo "  Cluster menu: off"; fi
    if [ "$TT" = 1 ]; then echo "  AA tap trace: ON (live)"; else echo "  AA tap trace: off"; fi
    if [ "$H" = 1 ] || [ "$HE" = 1 ]; then echo "  Hi-res: ON (next session)"; else echo "  Hi-res: off"; fi
    case "$P" in ''|0) echo "  Pump: off" ;; *) echo "  Pump: ${P}s (live)" ;; esac
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
