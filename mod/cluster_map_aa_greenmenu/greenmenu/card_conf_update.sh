#!/bin/sh
# card_conf_update.sh - persist switch keys for the hook WITHOUT an install.
#
# The hook's own config loader (load_config_file in gal_hook.c) reads its
# settings at every gal start from the FIRST file found among:
#   1. $GAL_HOOK_CONF          (if set)
#   2. /fs/sdb0/gal_dualscreen.conf
#   3. /fs/sda0/gal_dualscreen.conf
#   4. /eso/lib/gal_dualscreen/gal_dualscreen.conf   (the unit's copy)
#   5. /tmp/gal_dualscreen.conf
# A switch normally writes the UNIT's copy - but that needs the app
# partition remount, which on some boots refuses (the whole remount
# thread). The CARD-ROOT file is the escape hatch: it wins over the
# unit's copy by candidate order, and writing it needs only a card FAT
# remount - the one write every car grants (diag: the card copy has
# landed on every round since v0.5.3).
#
# IMPORTANT: the card file REPLACES the unit's copy for the loader, so it
# must be the UNION: the unit copy's lines + the new key.
#
#   card_conf_update.sh KEY=VALUE [KEY2=VALUE2 ...]
#   card_conf_update.sh --clear KEY          (remove a key from the card file)
#
# The card is remounted rw for the write window and back to ro after
# (the same contract as the diag card copy).
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

CONF_READ="$APP_MOUNT/eso/lib/gal_dualscreen/gal_dualscreen.conf"
if [ $# -eq 0 ]; then
    echo "usage: $0 KEY=VALUE [...] | --clear KEY" >&2
    exit 2
fi

CARD=""
for _c in /fs/sda0 /fs/sdb0 /net/mmx/fs/sda0 /net/mmx/fs/sdb0; do
    [ -d "$_c/mod/cluster_aa" ] && { CARD="$_c"; break; }
done
if [ -z "$CARD" ]; then
    echo "No card found (looked for mod/cluster_aa on every view)." >&2
    exit 1
fi

CARD_CONF="$CARD/gal_dualscreen.conf"
TMPF="$CARD/.cardconf.new.$$"

# remount the card rw for the write window (the diag copy's own contract)
if ! mount -uw "$CARD" 2>/dev/null; then
    echo "Cannot remount the card read-write. Nothing changed." >&2
    exit 1
fi

# build the union file: the unit copy's lines (minus keys we replace) +
# the new key=value pairs, through a new file and a rename
rm -f "$TMPF"
cp "$CONF_READ" "$TMPF" 2>/dev/null || : > "$TMPF"

_KEY=""
for a in "$@"; do
    case "$a" in
        --clear) MODE=clear ;;
        --clear=*) MODE=clear; _KEY=${a#--clear=} ;;
        *=*)
            K=${a%%=*}; V=${a#*=}
            sed -i "/^$K=/d" "$TMPF" 2>/dev/null
            echo "$K=$V" >> "$TMPF"
            ;;
    esac
done

if ! mv "$TMPF" "$CARD_CONF" 2>/dev/null; then
    rm -f "$TMPF" 2>/dev/null
    echo "Could not write $CARD_CONF. Nothing changed." >&2
    mount -ur "$CARD" 2>/dev/null
    exit 1
fi
sync
mount -ur "$CARD" 2>/dev/null
echo "Card conf updated: $CARD_CONF (the hook reads it at the next gal start - no install needed)"
exit 0
