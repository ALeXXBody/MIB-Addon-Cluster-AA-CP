#!/bin/sh

# install.sh — helper for an owner who has not already got the fork's SD-tree
# piped through a metainfo2 update. Run it ONCE from a PC with the M.I.B. SD
# card mounted, then remove. See install.md for the full documentation.
#
#   ./install.sh /path/to/MIB-SD-card           (Linux / macOS)
#   ./install.sh G:\\GIT_DIR                     (NOT supported — use WSL/cygnus)
#
# What it does:
#   1. Copies the fork's own per-unit binaries from $FORK_BIN (upstream
#      build or a release-bundled tarball) into the mod folder.
#   2. Adds the 4 GEM screens to the SD card's own Launcher-sda0.esd
#      file if the file is there and does not already have them.
#      (A unit with no JSONLINT-validation can still be brought up with
#      the upstream M.I.B. Launcher at the fork's docs).
#   3. Does not touch `/net/mmx/fs/sda0/apps/…` — M.I.B.'s own payload
#      (CarPlay Maps VC) is untouched and stays where M.I.B. writes it.

set -eu
FORK_BIN_DEFAULT=mod/cluster_map_aa_greenmenu/binaries
[ -d "${1:-}" ] || { echo "usage: ./install.sh <MIB-SDCARD-MOUNT>" >&2; exit 2; }
SDROOT=$1

# Some sanity checks.
for f in Launcher-sda0.esd mod apps esd; do
    [ -d "$SDROOT/$f" ] || { echo "Not an M.I.B. SD card: $f missing" >&2; exit 1; }
done
# Optional: confirm the fork's binaries exist.
if [ ! -f "${FORK_BIN_DEFAULT}/libgal_hook.so" ]; then
    echo "NOTE: no $FORK_BIN_DEFAULT/libgal_hook.so found.  Build with:"
    echo "      git clone https://github.com/ALeXXBody/mib-cluster-map-tiguan.git"
    echo "      cd ...; ./build_local.sh"
    echo "      cp dist/sdcard/… <SD>/mod/cluster_map_aa_greenmenu/binaries/"
fi

echo "Fork mod SD contents: install step 3, writing launcher GEM block."
L=$SDROOT/Launcher-sda0.esd
if [ ! -r "$L" ]; then
    echo "Launcher-sda0.esd is missing on the SD card — is M.I.B. correctly installed?". >&2; exit 1;
fi
if grep -q "cluster_map_aa" "$L" 2>/dev/null; then
    echo "Launchers already carry the Cluster Map screens: nothing to do."
else
    # Append the whole 4 screens block from esd/Launcher-sda0.esd.append.md
    cat esd/Launcher-sda0.esd.append.md >> "$L" && echo "Launcher-sda0.esd: appended 4 Cluster Map screens."
    sync
fi

echo
echo "Next steps:"
echo "  1. Reboot the unit into M.I.B.'s GEM."
echo "  2. Enter the new 'Cluster Map — Tiguan fork (AA→VC)' screens."
echo "  3. Press Install; run the fork's enable_hook.sh once from the SD fc0."
echo "  4. Connect a phone, start a map, switch the cluster to map view."
echo
exit 0
