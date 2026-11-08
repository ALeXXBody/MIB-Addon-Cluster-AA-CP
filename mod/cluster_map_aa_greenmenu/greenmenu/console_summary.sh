#!/bin/sh
# console_summary.sh — prints the CURATED "story" lines of a run log, so a
# GEM screen shows what happened in ~15 lines instead of pages.
# The full log goes on the card (the diag bundle writes it).
#   console_summary.sh <logfile>
F="$1"
[ -r "$F" ] || exit 0
sed -n \
    -e '/^M\.I\.B\. - /p' \
    -e '/^Phone map on the digital cluster/p' \
    -e '/^Head unit:/p' \
    -e '/^Firmware train:/p' \
    -e '/^Compatibility:/p' \
    -e '/^app partition:/p' \
    -e '/^system partition:/p' \
    -e '/^engdefs:/p' \
    -e '/^GEM screen:/p' \
    -e '/^Supervisor config:/p' \
    -e '/^stream-player:/p' \
    -e '/^Installed stream-player:/p' \
    -e '/^Installed settings copy:/p' \
    -e '/^Backed up the unit/p' \
    -e '/^Unit.s stock stream-player restored/p' \
    -e '/^Environment entries:/p' \
    -e '/^NOT /p' \
    -e '/^FAIL/p' \
    -e '/^ERROR/p' \
    -e '/^CRITICAL/p' \
    -e '/^WARNING/p' \
    -e '/^NOTE:/p' \
    -e '/^MISSING/p' \
    -e '/^ok: /p' \
    -e '/^unit files:/p' \
    -e '/^self-check:/p' \
    -e '/^Install finished/p' \
    -e '/^Uninstall finished/p' \
    -e '/^Sharper map/p' \
    -e '/^Zoom/p' \
    -e '/^Sharper-(map|open) switch/p' \
    -e '/^Hook: installed/p' \
    -e '/^Hook: not installed/p' \
    "$F" 2>/dev/null | head -25
