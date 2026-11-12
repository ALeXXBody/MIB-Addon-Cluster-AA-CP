#!/bin/sh
#
# card_clear.sh — “Turn-card clear of the route” switches (UX experiment).
#
# Background (docs/android-auto-research.md): Android Auto's protocol has an
# official UiConfig with content insets (opencardev proto: Insets
# top,bottom,left,right; the part of the frame the phone keeps free when it
# lays out the navigation card). This fork's hook already knows how to put
# that block into the cluster's video configuration
# (`build_insets_payload()` in src/video_sink_hook.c; the exploration and the
# mossyhub wire numbers are documented in docs/related-projects.md) — via a
# settings line, `GAL_SECONDARY_UI_CONFIG_HEX=`. What was missing is a
# legible in-car switch; this script is it.
#
# The hook fills the payload with the *current* insets when the hex line is
# absent, so the OFF direction removes the line — "stock behaviour".
#
#   card_clear.sh off | top | sides | band
#
#   off     remove the hex line (the standard fork insets apply)
#   top     declare a 60 px strip at the top free (the card tends to go up)
#   sides   declare 100 px on both sides free (card hugs the side)
#   band    declare top+bottom 60 px free (card to the middle band)
#
# Effect: at the NEXT phone connection (or unit reboot). Nothing restarts.
# Nothing else changes; the knobs are only a payload line in the installed
# settings file on the unit.
#
# Exit 0 switched; 3 nothing to change; on a read-only card/install = FAIL
# with message (See common.sh).
#
HERE=`dirname "$0"`
# the shared lib lives in the payload's scripts/ folder (round-13 class
# bug: a missing source line ABORTS the shell - guard it explicitly)
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
elif [ -r "$HERE/lib_app_mount.sh" ]; then
    . "$HERE/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi
CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"

case "$1" in
    off)   HEX="" ;;
    top)   HEX="5a041202083c" ;;
    sides) HEX="5a06120418642064" ;;
    band)  HEX="5a061204083c103c" ;;
    *) echo "usage: $0 off|top|sides|band" >&2; exit 2 ;;
esac

if [ ! -r "$CONF_READ" ]; then
    echo "The cluster map is not installed: install it first."
    exit 1
fi
# Player + hook facts on this unit match docs/related-projects.md: the
# content-insets knob lives in the hook; the installed stream-player does not
# change this behaviour. Nothing to check here besides a Settings file.

# Mount rw for the settings rewrite.
# Shared LADDER (the switch-audit fix): the single local spelling is not
# enough on cars whose console only remounts app via another view form
# (owner diag: "Cannot remount /mnt/app" killed EVERY switch silently).
# Write through the alias that actually took the remount.
if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write - every form failed:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
CONF="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
echo "app: read-write via '$APP_LADDER_FORM'"
APP_WRITABLE=1
trap app_mount_finish 0 1 2 15

# Read the currently set value (empty when not present).
NOW=`sed -n 's/^GAL_SECONDARY_UI_CONFIG_HEX=//p' "$CONF_READ" | tail -1`

if [ "$HEX" != "" ] && [ "$NOW" = "$HEX" ]; then
    echo "Turn-card clear ($1) already set. Nothing changed."
    exit 3
fi
if [ "$HEX" = "" ] && [ "$NOW" = "" ]; then
    echo "Turn-card clear: OFF is already active. Nothing changed."
    exit 3
fi

# tmp+mv rewrite (no sed -i: torn writes on FAT/QNX)
if [ "$HEX" = "" ]; then
    grep -v '^GAL_SECONDARY_UI_CONFIG_HEX=' "$CONF" > "$CONF.new" 2>/dev/null &&
    mv "$CONF.new" "$CONF" 2>/dev/null || {
        echo "Could not rewrite gal_dualscreen.conf. Nothing changed."; rm -f "$CONF.new"; exit 1; }
    echo "Turn-card clear: OFF (stock layout). Standard fork content insets."
else
    # Remove any stale hex line, add the chosen preset's payload, then sync.
    grep -v '^GAL_SECONDARY_UI_CONFIG_HEX=' "$CONF" > "$CONF.new" 2>/dev/null &&
    mv "$CONF.new" "$CONF" 2>/dev/null || {
        echo "Could not rewrite gal_dualscreen.conf. Nothing changed."; rm -f "$CONF.new"; exit 1; }
    echo "GAL_SECONDARY_UI_CONFIG_HEX=$HEX" >> "$CONF" || {
        echo "Could not append the settings line. Nothing changed."; exit 1; }
fi
sync

case "$1" in
    top)   TEXT="a 60 px strip at the top of the window is declared free." ;;
    sides) TEXT="100 px are declared free on the left and right sides." ;;
    band)  TEXT="top and bottom rows (60 px each) are declared free." ;;
    *)     TEXT="the standard layout: no extra content insets line." ;;
esac
echo "Turn-card clear: $1 — $TEXT"
echo ""
echo "Takes effect at your NEXT phone connection (or a unit reboot): the"
echo "phone lays out the cluster's map with these official content insets."
echo "If the layout does not change, the phone rejected the preset: run OFF"
echo "and post the Save-logs output."
echo ""
echo "OFF restores the standard layout without a re-install."
