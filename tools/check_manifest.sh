#!/bin/sh
# CI + local check: SHA256SUMS.txt must match a fresh hash over the payload's
# shipped file set (the same predicate tools/check_gem_esd.sh treats as code).
#
#   tools/check_manifest.sh            (from the repository root)
set -eu
cd "$(dirname "$0")/.."

PAYLOAD=mod/cluster_map_aa_greenmenu

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

(cd "$PAYLOAD" && find . -type f \( -name '*.sh' -o -name '*.esd' -o -name '*.conf' \
    -o -name '*.so' -o -name 'stream-player' -o -name 'profile_check' -o -name '*.jar' \) \
    | LC_ALL=C sort | xargs -d'\n' sha256sum) > "$TMP"

if diff -u "$PAYLOAD/SHA256SUMS.txt" "$TMP" >/tmp/manifest.diff 2>&1; then
    echo "check_manifest: OK ($(grep -c . $TMP) files)"
    exit 0
fi
echo "check_manifest: SHA256SUMS.txt is stale (see the diff below):"
head -30 /tmp/manifest.diff
exit 1
