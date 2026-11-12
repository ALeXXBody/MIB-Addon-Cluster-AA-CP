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
    -e '/^Could not /p' \
    -e '/^Could n[^o]/p' \
    -e '/^Generated /p' \
    -e '/^Staged /p' \
    -e '/^Persistent /p' \
    -e '/^Active config/p' \
    -e '/^Refusing/p' \
    -e '/^Installed config/p' \
    -e '/^Rebuilt/p' \
    -e '/^CLUSTERMAP_INSTALL_FAILED/p' \
    -e '/^.*INSTALL_FAILED/p' \
    -e '/^Uninstall FAILED/p' \
    -e '/^NOT SUPPORTED/p' \
    -e '/^CLUSTERMAP_UPDATE_FIRMWARE_FIRST/p' \
    -e '/^Forms tried/p' \
    -e '/^each with/p' \
    -e '/^Patch-temp/p' \
    -e '/^This is what/p' \
    -e '/^[a-z][a-z]*: can.t /p' \
    -e '/^awk: /p' \
    -e '/^grep: /p' \
    -e '/^sed: /p' \
    -e '/^sh: /p' \
    -e '/^mv: /p' \
    -e '/^chmod: /p' \
    -e '/^ok: /p' \
    -e '/^unit files:/p' \
    -e '/^self-check:/p' \
    -e '/^Done:/p' \
    -e '/^Cannot /p' \
    -e '/^Nothing changed/p' \
    -e '/^Switched/p' \
    -e '/^Keep[ -]map/p' \
    -e '/^Clearing/p' \
    -e '/^Cluster remote/p' \
    -e '/^Turn info strip:/p' \
    -e '/^Turn-card clear:/p' \
    -e '/^Nothing to/p' \
    -e '/^Porting bundle/p' \
    -e '/^Install finished/p' \
    -e '/^CLUSTERMAP_INSTALL_OK/p' \
    -e '/^CLUSTERMAP_TURN_BY_TURN_OK/p' \
    -e '/^Uninstall finished/p' \
    -e '/^Sharper map/p' \
    -e '/^Zoom/p' \
    -e '/^Sharper-(map|open) switch/p' \
    -e '/^Hook: installed/p' \
    -e '/^Hook: not installed/p' \
    "$F" 2>/dev/null | head -25
