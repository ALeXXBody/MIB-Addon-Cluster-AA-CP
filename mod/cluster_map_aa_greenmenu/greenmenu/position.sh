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

# write through the ladder like every switch
if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"

# POSIX-safe rewrite through a new file and rename (zoom.sh's way)
# the expert safer-area override REPLACES the insets AND the theme, so a
# remembered Turn-card preset would silently override the position: the
# override must go the moment an inset preset runs.
sed -e '/^GAL_SECONDARY_INSETS=/d' \
    -e '/^GAL_SECONDARY_UI_CONFIG_HEX=/d' \
    "$CONF" > "$CONF.new" 2>/dev/null
sed -e '/^GAL_SECONDARY_UI_CONFIG_HEX=/d' "$CONF" > "$CONF.new" 2>/dev/null
if ! echo "GAL_SECONDARY_INSETS=$NT,$NB,$NL,$NR" >> "$CONF.new" 2>/dev/null; then
    echo "Could not rewrite the insets in $CONF. Nothing changed."; rm -f "$CONF.new"; exit 1
fi
if grep -q "^GAL_SECONDARY_UI_CONFIG_HEX=" "$CONF" 2>/dev/null; then
    OVER="; removed the UI_CONFIG_HEX override (a Turn-card preset that would have blocked the inset change)"
else
    OVER=""
fi
mv "$CONF.new" "$CONF"
# v0.7.1: the insets are ALSO shipped live on the wire the way the
# ETA-card presets and the wheel menu do it - /tmp/gal_uiconfig is what
# the hook's ui-config sender turns into an immediate
# UpdateUiConfigRequest to the phone. The GEM's big shipdates stay:
# the phone's UiConfig *layout* is its own call, so the positions land
# now only when the phone accepts an update (normal on Android Auto 1.7).
echo "$NT,$NB,$NL,$NR" > /tmp/gal_uiconfig
sync
echo "Position: $ACTION (from $NOWSRC: $T,$B,$L,$R -> $NT,$NB,$NL,$NR; step $STEP px) LIVE SENT."
echo "Sent live on the wire; the next phone session re-derives it from the"
echo "unit's copy either way ('standard' is the shipped look)."
