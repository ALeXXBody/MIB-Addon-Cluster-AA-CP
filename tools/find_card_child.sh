#!/bin/sh
# find_card_test's child: stubs the mount binary, then sources the card
# locator inside a SUBSHELL and writes the found VOLUME/PKG to $RESULT_FILE.
# The related note: common.sh is a library but its not-found branch exits
# the shell; the subshell keeps an exit local, so the parent can still read
# the result file (absent = the not-found path ran).
mount() { if [ "$#" = 0 ]; then printf '%s\n' "$FAKE_TABLE"; return 0; fi; return 0; }
H=`dirname "$0"`
OUT="${RESULT_FILE:-/dev/null}"
(
    . "$H/../mod/cluster_map_aa_greenmenu/greenmenu/common.sh" >/dev/null 2>&1
    printf 'VOLUME=%s PKG=%s\n' "$VOLUME" "$PKG" > "$OUT"
) >/dev/null 2>&1
