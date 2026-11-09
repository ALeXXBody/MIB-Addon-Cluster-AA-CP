#!/bin/sh
# etacard.sh - the ETA card's own pose presets (the "green card": the
# turn banner with the ETA/directions the phone draws on the cluster).
#
# The knob is Android Auto's own UiConfig content inset: a SINGLE EDGE
# declared free moves the safe area's onset, which plants the banner on
# that edge - the same field the shipped "Turn-card clear" presets use,
# extended to all four edges (the 800x480 frame of the AA stream):
#   top    = 08 3c   (field 1 = 60) -> the shipped "top strip"
#   bottom = 10 3c   (field 2 = 60) -> NEW: banner to the bottom strip
#   left   = 18 3c   (field 3 = 60) -> NEW: banner as a left column
#   right  = 20 3c   (field 4 = 60) -> NEW: banner as a right column
#   off    remove the hex line: the stock insets apply again
#
# Effect at the NEXT phone session (or unit reboot); nothing restarts.
# The hex REPLACES the plain insets and the theme - the Position presets
# remember that and clear this key when they run.

HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
case "$1" in
    top)    HEX="5a041202083c"; POSE="a 60 px strip at the top of the frame is declared free" ;;
    bottom) HEX="5a041202103c"; POSE="a 60 px strip at the bottom of the frame is declared free" ;;
    left)   HEX="5a041202183c"; POSE="a 60 px column at the left is declared free" ;;
    right)  HEX="5a041202203c"; POSE="a 60 px column at the right is declared free" ;;
    broad_top) HEX="5a041202084c"; POSE="the top strip is widened to 76 px" ;;
    off)    HEX=""; POSE="the standard layout (the hook's own insets apply)";;
    *) echo "usage: $0 top|bottom|left|right|broad_top|off" >&2; exit 2 ;;
esac

if [ ! -r "$CONF_READ" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi

# Write through the ladder like every switch
if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"

NOW=`sed -n 's/^GAL_SECONDARY_UI_CONFIG_HEX=//p' "$CONF_READ" | tail -1`
if [ "$HEX" != "" ] && [ "$NOW" = "$HEX" ]; then
    echo "ETA card ($1) already set. Nothing changed."
    exit 0
fi

sed -i '/^GAL_SECONDARY_UI_CONFIG_HEX=/d' "$CONF" || {
    echo "Could not rewrite gal_dualscreen.conf. Nothing changed."; exit 1; }
if [ "$HEX" != "" ]; then
    echo "GAL_SECONDARY_UI_CONFIG_HEX=$HEX" >> "$CONF" || {
        echo "Could not append the settings line. Nothing changed."; exit 1; }
fi
sync

if [ "$HEX" = "" ]; then
    echo "ETA card: OFF - $POSE."
else
    echo "ETA card: $1 - $POSE."
fi
echo "Lands at the NEXT phone connection (or unit reboot): the phone lays"
echo "out the turn banner with this edge free; the banner takes that edge."
echo "If the layout does not move, the phone rejected the pose: run OFF and"
echo "send the Save-logs bundle. The hex overrides the plain insets and the"
echo "theme - a Position preset clears it automatically when you go back."
