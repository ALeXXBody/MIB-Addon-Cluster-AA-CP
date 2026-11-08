#!/bin/sh
# check_release_build.sh — the ONE-CLICK contract of the shipped zip.
#
# The owner's rule: download, copy mod/, one click in the GEM, done. That is
# only true if the release payload carries the arm marker: the zip's payload
# is armed, the REPOSITORY's payload stays unarmed (so tests/dev can never
# arm a unit by accident). Both halves are asserted here on a real build.
#
#   tools/check_release_build.sh          (from the repository root)
set -eu
cd "$(cd "$(dirname "$0")/.." && pwd)"

TAG=contract-check
ZIP="dist/MIB-Addon-Cluster-AA-CP-mod-$TAG.zip"

cleanup() { rm -rf dist; }
trap cleanup EXIT

sh tools/build_release.sh "$TAG" >/dev/null

[ -f "$ZIP" ] || { echo "check_release_build: FAILED (no zip)"; exit 1; }
if ! unzip -l "$ZIP" | grep -q "mod/cluster_aa/HOOK_ARMED$"; then
    echo "check_release_build: FAILED (zip does not ship HOOK_ARMED)"
    exit 1
fi
if ! unzip -p "$ZIP" "MIB-Addon-Cluster-AA-CP-mod/mod/cluster_aa/VERSION" \
        2>/dev/null | grep -qx "$TAG"; then
    echo "check_release_build: FAILED (zip VERSION does not name the tag)"
    exit 1
fi
if [ -e mod/cluster_map_aa_greenmenu/HOOK_ARMED ]; then
    echo "check_release_build: FAILED (the REPOSITORY payload is armed)"
    exit 1
fi
# A one-click zip must not contain the old folder name inside mod/ either:
# one payload, one path, no stale duplicate.
if unzip -l "$ZIP" | grep -q "mod/cluster_map_aa_greenmenu/"; then
    echo "check_release_build: FAILED (old payload folder name in the zip)"
    exit 1
fi
# The diagnostic file must never be a shipped, stale file.
if unzip -l "$ZIP" | grep -qE "diag\.txt"; then
    echo "check_release_build: FAILED (a diag.txt was shipped in the zip)"
    exit 1
fi
echo "check_release_build: OK (one-click payload armed, repo payload unarmed)"
