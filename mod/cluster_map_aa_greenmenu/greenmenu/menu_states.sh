#!/bin/sh
# menu_states.sh - one-line feature summary for the main menu's States row.
#
#   menu_states.sh [conf_file]
#
# Prints e.g. "States: remote, wheel, zoom 1.15" or "States: stock (all
# off)". Reads the installed settings copy (first readable app-view
# spelling, or the file named on the command line) plus the hook's live
# /tmp flags -- never remounts, never writes, never fails (exit 0,
# "States: --" when nothing is readable). Read-only by design: both the
# installer (custom.sh, baking the screen) and the menu refresh path
# (menus.sh run_quiet, after every press) call it.
HERE=`dirname "$0"` || HERE=""
RT="${GAL_RUNTIME_DIR:-/tmp}"

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

# remote: the hook reads the live flag at every gesture.
R=`lkey gal_remote` || R=""
[ "$R" = 1 ] && add "remote"

# wheel: enabled unless the conf explicitly opts out; needs the HMI
# tracer ports, so a silent port pair earns the reboot reminder. Without
# any readable conf there is nothing to report (never assume ON).
W=""
[ -r "$CONF" ] && W=`ckey GAL_WHEEL_LISTEN` || W=""
if [ -r "$CONF" ] && [ "$W" != 0 ]; then
    if command -v netstat >/dev/null 2>&1; then
        if netstat -an 2>/dev/null | grep -qE "[:.]1798 |[:.]20991 "; then
            add "wheel"
        else
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

# turn strip: live file present and 1.
N=`lkey stream-player.navstrip` || N=""
[ "$N" = 1 ] && add "strip"

# card clear: any armed uiconfig (absent = full window, nothing to show).
if [ -r "$RT/gal_uiconfig" ]; then add "card"; fi

# sharpness pump: positive level.
P=`lkey gal_idr_pump` || P=""
case "$P" in ''|0) ;; *) add "pump" ;; esac

# hi-res: live flag or conf key.
H=`lkey gal_hires` || H=""
[ "$H" = 1 ] && add "hires"
if [ "$H" != 1 ]; then
    HE=`ckey GAL_SECONDARY_HIRESEN` || HE=""
    [ "$HE" = 1 ] && add "hires"
fi

if [ -z "$S" ]; then
    echo "States: stock (all off)"
else
    echo "States: $S"
fi
exit 0
