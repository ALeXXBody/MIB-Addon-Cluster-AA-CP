#!/bin/sh
#
# install.sh — stage this M.I.B. Addon on an already-made M.I.B. SD card.
#
# Run it on the host with the M.I.B. SD card mounted as the first argument.
# It only writes *to the card*; nothing touches the unit.
#
#   ./install.sh /media/A1B2-C3D4            (Linux / macOS / WSL)
#
# What it does:
#   1. Requires the M.I.B. SD card (Launcher-sda0.esd / mod / apps / esd)
#      to already be present — so M.I.B. is installed, not just copied.
#   2. Copies this repo's mod/cluster_map_aa_greenmenu/ onto the
#      card's mod/… folder (upstream mib-cluster-map v1.1.0 payload,
#      car-tested on Tiguan AD1 / VWG13).
#   3. Copies this repo's esd/scripts/cm_aa_*.sh into the card's
#      esd/scripts/ so M.I.B.'s own GEM keeps its own scripts intact.
#   4. Splices the 4 new GEM screens into the card's Launcher-sda0.esd
#      file (idempotent: does not double-add).
#   5. Warns (but does not block) if the Tiguan-owner needs to also apply
#      M.I.B.'s option 7 (CarPlay & Android Auto activation) first.
#
set -eu
[ -d "${1:-}" ] || { echo "usage: $0 <M.I.B.-SD-card-mount-point>" >&2; exit 2; }
SDROOT=$1

# 1. sanity checks
for d in Launcher-sda0.esd mod esd apps patches; do
    [ -e "$SDROOT/$d" ] || { echo "Not an M.I.B. SD card: '$d' is missing." >&2; exit 1; }
done
echo "M.I.B. SD card verified at $SDROOT."

# 2. copy the mod payload
echo "Copying mod/cluster_map_aa_greenmenu/ ..."
mkdir -p "$SDROOT/mod/cluster_map_aa_greenmenu"
cp -r -- mod/cluster_map_aa_greenmenu/. "$SDROOT/mod/cluster_map_aa_greenmenu/"

# 3. copy the GEM wrappers
for s in cm_aa_status.sh cm_aa_install.sh cm_aa_uninstall.sh cm_aa_collect.sh; do
    if [ -f "esd/scripts/$s" ]; then
        echo "Copying esd/scripts/$s ..."; cp -p "esd/scripts/$s" "$SDROOT/esd/scripts/"
    fi
done

# 4. splice the GEM screen block
L="$SDROOT/Launcher-sda0.esd"
if grep -q "cluster_map_aa" "$L" 2>/dev/null; then
    echo "Launcher already has the Cluster Map screens: not doubled."
else
    if [ -f "esd/Launcher-sda0.esd.append.md" ]; then
        echo "Splicing the GEM screen block..."
        cat esd/Launcher-sda0.esd.append.md >> "$L"
        sync
        echo "Launcher-sda0.esd updated: 4 Cluster AA/CP screens added."
    fi
fi

echo
echo "== Next steps =="
echo "  1. Put this SD card into SD slot 1 of the unit."
echo "  2. Boot into M.I.B. GEM (hold MENU > Testmode); the mod screens are there."
echo "  3. Use 'Status' first to see the hook state."
echo "  4. Use 'Install' to install the fork's AA→VC."
echo "     M.I.B. option 7 (CarPlay/AA coding) must already have been applied"
echo "     (most units already have it after a full M.I.B. install)."
echo "  5. Connect a phone and switch the cluster to map view."
echo
echo "Done."
exit 0
