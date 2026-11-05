#!/bin/sh
# Build the owner-facing release zip: everything an owner needs on an M.I.B.
# SD card, one file to download.
#
#   tools/build_release.sh [<tag>]          (from the repository root)
#   tools/build_release.sh v0.4.0
# Output:
#   dist/MIB-Addon-Cluster-AA-CP-mod-<tag>.zip         the card payload
#   dist/MIB-Addon-Cluster-AA-CP-mod-<tag>.zip.sha256  checksum
set -eu
cd "$(dirname "$0")/.."

TAG=${1:-local-test}
NAME="MIB-Addon-Cluster-AA-CP-mod"
DIST=dist
rm -rf "$DIST"
mkdir -p "$DIST/$NAME"

# The card payload plus the two owner documents and the licence.
cp -r mod README.md install.md LICENSE docs "$DIST/$NAME/"
# Screenshots live in git, not in a release an owner copies to FAT32:
rm -rf "$DIST/$NAME/docs/photos"

if ! command -v zip >/dev/null 2>&1; then
    echo "ERROR: 'zip' not found" >&2
    exit 1
fi
(cd "$DIST" && zip -qr "$NAME-$TAG.zip" "$NAME")
(cd "$DIST" && sha256sum "$NAME-$TAG.zip" > "$NAME-$TAG.zip.sha256")

echo "Release artifacts in $DIST/:"
ls -la "$DIST"
echo
echo "Contents:"
(cd "$DIST/$NAME" && find . -maxdepth 2 | sort | head -40)
