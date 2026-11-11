#!/bin/sh
# card_conf_update.sh - persist switch keys for the hook WITHOUT an install.
#
# The hook's config loader (load_config_file in gal_hook.c) reads its
# settings at every gal start from the FIRST file found among:
#   1. $GAL_HOOK_CONF          (if set)
#   2. /fs/sdb0/gal_dualscreen.conf
#   3. /fs/sda0/gal_dualscreen.conf
#   4. /eso/lib/gal_dualscreen/gal_dualscreen.conf   (the unit's copy)
#   5. /tmp/gal_dualscreen.conf
# A card-root file therefore SHADOWS the unit copy, and it must be the
# UNION: the unit copy's lines plus the change, or the hook loses every
# setting the unit copy carried.
#
# This script is the manual/GEM entry point for that file. The switches
# themselves call conf_persist() in scripts/lib_app_mount.sh, which uses
# the same writer (conf_card_write) and picks the card file whenever it
# already exists.
#
#   card_conf_update.sh KEY=VALUE [KEY2=VALUE2 ...]
#   card_conf_update.sh KEY=                  (remove a key)
#   card_conf_update.sh --clear KEY           (remove a key)
#
# The card is remounted rw for the write window and back to ro after (the
# same contract as the diag card copy). Every write is verified by
# readback before it is claimed.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "usage: $0 KEY=VALUE [...] | KEY= | --clear KEY" >&2
    exit 2
fi

MODE=set
if [ "$1" = "--clear" ]; then
    MODE=clear
    shift
    [ $# -gt 0 ] || { echo "usage: $0 --clear KEY" >&2; exit 2; }
fi

if ! conf_card_write "$MODE" "$@"; then
    echo "Card settings NOT updated. Nothing changed." >&2
    exit 1
fi
echo "Card settings updated: $CONF_PERSIST_WHERE"
echo "(the hook reads this file at the next gal start - no install needed)"
exit 0
