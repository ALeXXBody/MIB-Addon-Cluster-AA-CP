#!/bin/sh
# CI + local check: SHA256SUMS.txt must match a fresh hash over the payload's
# shipped file set (the same predicate tools/check_gem_esd.sh treats as code).
#
#   tools/check_manifest.sh            (from the repository root)
set -eu
cd "$(dirname "$0")/.."

PAYLOAD=mod/cluster_map_aa_greenmenu

TMP=$(mktemp)
DIFFTMP=$(mktemp)
trap 'rm -f "$TMP" "$DIFFTMP"' EXIT

(cd "$PAYLOAD" && find . -type f \( -name '*.sh' -o -name '*.esd' -o -name '*.conf' \
    -o -name '*.so' -o -name 'stream-player' -o -name 'profile_check' -o -name '*.jar' \) \
    -print0 | LC_ALL=C sort -z | xargs -0 sha256sum) > "$TMP"

if diff -u "$PAYLOAD/SHA256SUMS.txt" "$TMP" >"$DIFFTMP" 2>&1; then
    echo "check_manifest: OK ($(grep -c . $TMP) files)"
    exit 0
fi
echo "check_manifest: SHA256SUMS.txt is stale (see the diff below):"
head -30 "$DIFFTMP"
exit 1
