#!/bin/sh
# Build the owner-facing release zip: exactly the files that go on the
# M.I.B. SD card — and nothing that could overwrite a M.I.B. card file.
#
#   tools/build_release.sh [<tag>]          (from the repository root)
#
# Output:
#   dist/MIB-Addon-Cluster-AA-CP-mod-<tag>.zip
#     ├── HOW-TO-INSTALL.txt                       (the 3 steps; zip-only file)
#     ├── MIB-Addon-Cluster-AA-CP-LICENSE.txt      (the GPL text; zip-only)
#     └── mod/                                     (everything that goes
#         ├── custom.sh                               on the card)
#         └── cluster_aa/…
#   dist/MIB-Addon-Cluster-AA-CP-mod-<tag>.zip.sha256
#
# Why NOT the repo's README.md / LICENSE / docs: M.I.B.'s own card root
# already carries its own LICENSE and README.md — if an owner copies the
# whole zip root to the card, ours would overwrite theirs. The owner-facing
# files therefore use names that cannot collide, stay in the zip only, and
# the card gets ONLY the mod/ folder.
set -eu
cd "$(dirname "$0")/.."

TAG=${1:-local-test}
NAME="MIB-Addon-Cluster-AA-CP-mod"
DIST=dist
rm -rf "$DIST"
mkdir -p "$DIST/$NAME/mod"

cp -r mod/cluster_map_aa_greenmenu "$DIST/$NAME/mod/cluster_aa"
cp mod/custom.sh "$DIST/$NAME/mod/"
cp LICENSE "$DIST/$NAME/MIB-Addon-Cluster-AA-CP-LICENSE.txt"

# generated so the tag name lands inside the file
cat > "$DIST/$NAME/HOW-TO-INSTALL.txt" <<HTI
HOW TO INSTALL — M.I.B. Addon: Cluster AA/CP  (archive $TAG, MOD ONLY)
=====================================================================

This zip contains ONLY the files that go on your M.I.B. SD card:

    mod/custom.sh                          - the one-click hook
    mod/cluster_aa/...                     - the payload; every switch lives
                                             in M.I.B.'s GEM under
                                             "Cluster map" after install
    MIB-Addon-Cluster-AA-CP-LICENSE.txt    - the GPL-3.0 licence text
                                             (keep on your PC; do not copy
                                             onto the card - M.I.B. has its
                                             own files at the card root)

The steps (3 of them):

1. PREPARE: M.I.B. installed and working in GEM ("=>m.i.b.<=" shows in the
   GEM tree). If not: install M.I.B. first (the M.I.B. Launcher is its own
   SD card update flow).

2. COPY: unzip. Copy the WHOLE 'mod/' folder into the root of your M.I.B.
   SD card, merging with the card's own mod/ folder
   (do NOT copy anything else from the zip onto the card - M.I.B.'s card
   root already has its own README/LICENCE and ours would overwrite them).

3. ONE CLICK: SD1 in the unit; open M.I.B.'s GEM
   (M.I.B. -> Advanced settings -> "Run /mod/custom.sh from m.i.b. SD").
   The "Cluster map" page appears in the GEM menu at the next boot.

First look at the new Cluster map page:
   Status (your unit's profile) -> the switches (Turn-card clear, Turn
   info strip, Zoom, Cluster remote) -> Uninstall and Save logs.

THE MAP STAYS STOCK UNTIL YOU ARM IT (deliberate, v0.4.20 default):
   the run stages the files only. To make the map live, put an empty file
   named HOOK_ARMED (or ARMNOW.TXT) into mod/cluster_aa/ on the card and
   run the same "Run /mod/custom.sh" entry once more.
   If you had an older version: delete mod/cluster_map_aa_greenmenu/ from
   the card afterwards (the new folder is mod/cluster_aa; both are found,
   but only one is needed).

ONE FILE TO SEND IF ANYTHING LOOKS WRONG:
   every run writes a diagnostic file and prints its name on the GEM
   screen. It is /tmp/clustermap_diag/diag.txt on the unit and is also
   copied to the card as mod/cluster_aa/diag.txt. Send that single file
   (plus a photo of the cluster if the map is the issue) - it carries the
   unit/train facts, the installed map settings and the full run log, so
   the add-on can be diagnosed and the picture tuned from it. Nothing on
   the card is written during a normal run (that was what made the card
   look read-only); the card gets only that one copy, best-effort.

Full docs (photos, troubleshooting, updates): the repository README
https://github.com/ALeXXBody/MIB-Addon-Cluster-AA-CP
and the release page of this version ("what's new").
HTI

if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: 'zip' not found" >&2
    exit 1
fi
(cd "$DIST" && zip -qr "$NAME-$TAG.zip" "$NAME")
(cd "$DIST" && sha256sum "$NAME-$TAG.zip" > "$NAME-$TAG.zip.sha256")

echo "Release artifacts in $DIST/:"
ls -la "$DIST"
echo
echo "Zip contents (root level):"
unzip -l "$DIST/$NAME-$TAG.zip" 2>/dev/null | grep -E "HOW-TO|LICENSE|mod/" | grep -vE "cluster_aa/" | head -8
