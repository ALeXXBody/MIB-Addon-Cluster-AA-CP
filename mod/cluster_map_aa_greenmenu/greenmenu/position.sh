#!/bin/sh
# position.sh - WHERE the map and its content sit in the cluster window.
# The insets (GAL_SECONDARY_INSETS top,bottom,left,right, inside the
# 800x480 frame) are the phone's safe area: they move the content box
# (turn card, labels, speed limit) inside the map window - the position
# lever the cluster layout offers. Each value 0..127, inside the frame.
#   position.sh higher|lower|wider|narrower|standard [STEP]
# STEP defaults to 8 px; a new value lands at the NEXT phone session.

HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

case "$2" in
    ''|*[!0-9]*) STEP=8 ;;
    *)           STEP=$2 ;;
esac
[ "$STEP" -gt 40 ] && STEP=40

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"

case "$1" in
    higher|lower|wider|narrower|standard) : ;;
    *) echo "usage: $0 higher|lower|wider|narrower|standard [STEP]" >&2; exit 2 ;;
esac
ACTION="$1"

NOW=`sed -n 's/^GAL_SECONDARY_INSETS=\([0-9]*\),\([0-9]*\),\([0-9]*\),\([0-9]*\)[   ]*$/\1 \2 \3 \4/p' "$CONF_READ" 2>/dev/null | tail -1`
if [ -z "$NOW" ]; then
    # the installer's "auto" or a missing line: the shipped default
    NOW="40 40 127 127"
    NOWSRC="the installed default (40,40,127,127)"
else
    NOWSRC="the installed values"
fi

# keep every command substitution on a single, flat level - the nested
# backtick forms echo junk onto this unit's shell (round-27's class)
T=$NOW; B=$NOW; L=$NOW_DIR; R=$NOW_R
set -- $NOW
T=$1; B=$2; L=$3; R=$4

clamp_lt()   # clamp_lt VALUE DELTA: VALUE-DELTA, clamped 0..127
{
    R=`expr \( $1 \) - \( $2 \) || :`
    [ "$R" -lt 0 ] && R=0
    [ "$R" -gt 127 ] && R=127
    echo "$R"
}
clamp_gt()   # clamp_gt VALUE DELTA: VALUE+DELTA, clamped 0..127
{
    R=`expr \( $1 \) + \( $2 \) || :`
    [ "$R" -lt 0 ] && R=0
    [ "$R" -gt 127 ] && R=127
    echo "$R"
}

NT=$T; NB=$B; NL=$L; NR=$R
case "$ACTION" in
    higher)
        NT=`clamp_lt $T $STEP`
        NB=`clamp_gt $B $STEP`
        ;;
    lower)
        NT=`clamp_gt $T $STEP`
        NB=`clamp_lt $B $STEP`
        ;;
    wider)
        NL=`clamp_lt $L $STEP`
        NR=`clamp_lt $R $STEP`
        ;;
    narrower)
        NL=`clamp_gt $L $STEP`
        NR=`clamp_gt $R $STEP`
        ;;
    standard)
        NT=40; NB=40; NL=127; NR=127
        ;;
esac

# v0.7.5: the LIVE wire send comes FIRST and survives a refused remount.
# /tmp/gal_uiconfig is what the hook's ui-config sender turns into an
# immediate UpdateUiConfigRequest to the phone (GAL_UICONFIG=1 in the
# settings turns the sender on); the persisted key only matters for the
# next phone session.
live_write "$GAL_RUNTIME_DIR/gal_uiconfig" "$NT,$NB,$NL,$NR" || exit 1

PERSISTED=0
# The expert safer-area override REPLACES the insets AND the theme, so a
# remembered Turn-card preset would silently override the position: clear
# it in the same write. Empty value = remove that key.
OVER=""
_ACTIVE_CONF=`conf_card_file` || _ACTIVE_CONF="$CONF_READ"
grep -q "^GAL_SECONDARY_UI_CONFIG_HEX=" "$_ACTIVE_CONF" 2>/dev/null &&
    OVER="; removed the UI_CONFIG_HEX override"
conf_persist set "GAL_SECONDARY_INSETS=$NT,$NB,$NL,$NR" "GAL_SECONDARY_UI_CONFIG_HEX=" && {
    if [ "$CONF_PERSISTED" = 1 ]; then PERSISTED=1; else PERSISTED=2; fi
}

echo "Position: $ACTION (from $NOWSRC: $T,$B,$L,$R -> $NT,$NB,$NL,$NR; step $STEP px)."
case "$PERSISTED" in
    1) echo "Live request queued: the hook sends it to the phone now when GAL_UICONFIG=1."
       echo "Persisted in the unit's copy$OVER: the next phone session re-derives it." ;;
    2) echo "Live request queued: the hook sends it to the phone now when GAL_UICONFIG=1."
       echo "Persisted on the card root$OVER: the next gal start re-derives it." ;;
    *) echo "NOT persisted (both write paths refused): only the live request above is in"
       echo "effect; the next phone session returns to the previous insets." ;;
esac
