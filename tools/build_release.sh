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

# ONE CLICK BY DEFAULT: the shipped payload carries the arm marker, so the
# single "Run /mod/custom.sh" both registers the GEM screen and makes the
# map live (screen file is validated first, then the hook). Delete this file
# from the card if you want a stage-only run. The repository's own payload
# stays UNARMED, so development/testing can never arm a unit by accident.
: > "$DIST/$NAME/mod/cluster_aa/HOOK_ARMED"
# The owner (and remote diagnosis) must be able to SEE which payload an
# install is running: every GEM run prints this file's content. The tag
# names it, the zip carries it, the GEM console shows it.
echo "$TAG" > "$DIST/$NAME/mod/cluster_aa/VERSION"

# generated so the tag name lands inside the file
cat > "$DIST/$NAME/HOW-TO-INSTALL.txt" <<HTI
HOW TO INSTALL — M.I.B. Addon: Cluster AA/CP  (archive $TAG, MOD ONLY)
=====================================================================

This zip contains ONLY the files that go on your M.I.B. SD card:

    mod/custom.sh                          - the one-click hook
    mod/cluster_aa/...                     - the payload; every switch lives
                                             in M.I.B.'s GEM under
                                             "Cluster map" after install
    mod/cluster_aa/HOOK_ARMED              - makes the one click install the
                                             map LIVE (validated screen first,
                                             then the hook). Delete it if you
                                             want a stage-only, no-change run
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
   That single run: validates and installs the GEM screen, installs the
   hook, backs up the unit's stock player, and makes the map live.
   Then reboot (power button ~10 s) - the map is on the cluster.

IF EVERY CLUSTERMAP BUTTON SAYS "Script not found":
   the screen on the unit names a payload path that is no longer on the
   card (true for updates before v0.4.21 - the payload folder was renamed
   from mod/cluster_map_aa_greenmenu to mod/cluster_aa). One rerun of
   "Run /mod/custom.sh" re-anchors the screen, then reboot. The folder
   name mod/cluster_aa is frozen from v0.4.23 onwards - future updates
   never change it, so this cannot happen again.

WHICH VERSION IS ON MY CARD?  every run in the GEM prints the payload
   version on its console ("payload on the card: vX.Y.Z"). If that line
   still names an older version after you copied a newer zip's mod/ onto
   the card, the copy did NOT land - copy mod/ again (merge over it), or
   the card is full / read-only and nothing could be written.

First look at the new Cluster map page:
   Status (your unit's profile) -> the switches (Turn-card clear, Turn
   info strip, Zoom, Cluster remote) -> Uninstall and Save logs.

IF THE MAP DOES NOT APPEAR (or you want to go step by step):
   put the card back in a PC, delete mod/cluster_aa/HOOK_ARMED, and run the
   same "Run /mod/custom.sh" entry again - that stages the files only and
   changes nothing on the unit. Re-add the file when you want it live.
   If you had an older version: delete mod/cluster_map_aa_greenmenu/ from
   the card afterwards (the new folder is mod/cluster_aa; both are found,
   but only one is needed).

IF THE SCREEN SAYS "card copy: NOT WRITTEN":
   the map still installs (that is read-side, which always works), but the
   card is mounted read-only by the unit - almost always because the card
   was pulled from a PC without a proper eject. Fix on the PC: put the card
   back and eject it properly (or chkdsk /f X: once), then use the GEM's
   "10/11. Save logs" entry and the diag.txt appears on the card. Until
   then, photograph the screen: it prints the tuning facts right below.

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
# The APPLY section (card update? one more GEM click? reboot?) is computed
# from the real diff between the previous tag and THIS tag and appended to
# the shipped HOW-TO (nothing here needs the release's own regime decisions).
PREV_TAG=$(git tag --sort=-creatordate | grep -v "^$TAG$" | head -1)
{ echo
  if [ -n "$PREV_TAG" ]; then
      sh tools/release_guide.sh "$PREV_TAG" "$TAG" 2>/dev/null || true
  else
      echo "(first release: the full install flow is the HOW-TO above)"
  fi; } >> "$DIST/$NAME/HOW-TO-INSTALL.txt"

if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: 'zip' not found" >&2
    exit 1
fi
(cd "$DIST" && zip -qr "$NAME-$TAG.zip" "$NAME")

# The one-click contract: the shipped payload MUST carry the arm marker, and
# the repo's own payload MUST NOT (so tests/dev can never arm a unit).
[ -f "$DIST/$NAME/mod/cluster_aa/HOOK_ARMED" ] || {
    echo "ERROR: HOOK_ARMED missing from the release payload" >&2; exit 1; }
# ... and it must be a version the owner can see in the GEM:
[ -s "$DIST/$NAME/mod/cluster_aa/VERSION" ] || {
    echo "ERROR: VERSION missing from the release payload" >&2; exit 1; }
[ -f "mod/cluster_map_aa_greenmenu/HOOK_ARMED" ] && {
    echo "ERROR: the REPOSITORY payload is armed; tests must stay unarmed" >&2
    exit 1; }
unzip -l "$DIST/$NAME-$TAG.zip" 2>/dev/null | grep -q "mod/cluster_aa/HOOK_ARMED" || {
    echo "ERROR: HOOK_ARMED did not make it into the zip" >&2; exit 1; }
grep -qx "$TAG" "$DIST/$NAME/mod/cluster_aa/VERSION" || {
    echo "ERROR: VERSION does not name this tag" >&2; exit 1; }
[ -f "mod/cluster_map_aa_greenmenu/VERSION" ] && {
    echo "ERROR: the REPOSITORY payload carries a VERSION (stale marker)" >&2
    exit 1; }

(cd "$DIST" && sha256sum "$NAME-$TAG.zip" > "$NAME-$TAG.zip.sha256")

echo "Release artifacts in $DIST/:"
ls -la "$DIST"
echo
echo "Zip contents (root level):"
unzip -l "$DIST/$NAME-$TAG.zip" 2>/dev/null | grep -E "HOW-TO|LICENSE|mod/" | grep -vE "cluster_aa/" | head -8
