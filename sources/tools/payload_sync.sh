#!/bin/sh
# payload_sync.sh — keeps the fork's sd-payload and the Addon's shipped
# payload identical. Two copies of one tree in two repositories is a drift
# risk; this script is the check and, with --apply, the fix.
#
#   tools/payload_sync.sh <path-to-MIB-Addon-Cluster-AA-CP>          # check
#   tools/payload_sync.sh <path-to-MIB-Addon-Cluster-AA-CP> --apply  # sync
#
# The Addon's payload is the shipping one (what cards actually receive), so
# this script copies FROM the Addon repo INTO mib-mod/sd-payload/... of this
# repository and reports any drift first.
#
# Layout rules this script encodes:
#   * Shared layout: the Addon's tree is copied over this tree, path for
#     path (enable_hook.sh at root, greenmenu/..., scripts/<libs>...).
#   * Nested duplicates: the fork's M.I.B. screens (esd/scripts/cm_aa_*.sh)
#     reach enable_hook.sh / disable_hook.sh / collect_logs.sh through the
#     NESTED layout scripts/<name>.sh. Those entries are only sound when
#     they byte-match the canonical Addon file; the mapping below is the
#     single place that names them. They are judged by that rule, NOT by
#     the shared-tree diff.
#   * Fork-only extras (binaries/, config/, custom.sh, README.md) are this
#     tree's own productization and are excluded from comparison.
#
# History note: the first revision of this checker reported "OK, no drift"
# unconditionally — `diff -u ... | head` piped the real exit status into
# head's (always-success) status. Silent drift is exactly the failure class
# this script exists to prevent; the compare below never pipes diff.
set -u
HERE=`dirname "$0"`
REPO=`cd "$HERE/.." && pwd`

ADDON_DIR=${1:-}
if [ -z "$ADDON_DIR" ] || [ ! -d "$ADDON_DIR/mod/cluster_map_aa_greenmenu" ]; then
    echo "usage: $0 <path-to-MIB-Addon-Cluster-AA-CP-repo> [--apply]" >&2
    exit 2
fi
case "${2:-}" in --apply) APPLY=1 ;; *) APPLY=0 ;; esac

SRC="$ADDON_DIR/mod/cluster_map_aa_greenmenu"
DST="$REPO/mib-mod/sd-payload/cluster_map_aa_greenmenu"

# "nested copy : canonical Addon-root file" — entries that exist ONLY in
# this tree (the Addon tree has no such nested path, so tar overlay cannot
# keep them in sync). The Addon also lsd_jar.sh / turn_by_turn.sh nested in
# scripts/ — those are shared paths and the plain overlay syncs them.
DUP_MAP="scripts/enable_hook.sh:enable_hook.sh
scripts/disable_hook.sh:disable_hook.sh
scripts/collect_logs.sh:collect_logs.sh"

hashset() {
    cd "$1" && find . -type f \( -name '*.sh' -o -name '*.esd' -o -name '*.conf' \
        -o -name '*.so' -o -name 'stream-player' -o -name 'profile_check' \
        -o -name '*.jar' \) | LC_ALL=C sort | xargs -d'\n' sha256sum
}

echo "checking payload drift:"
echo "  src = $SRC"
echo "  dst = $DST"
echo "(differences below are the drift; --apply copies the Addon's files over)"

TMPD=`mktemp -d`
trap 'rm -rf "$TMPD"' EXIT
hashset "$SRC" > "$TMPD/src.sha"
hashset "$DST" > "$TMPD/dst.sha"

# dst.shared = dst's hash list with fork-only paths and nested-dup entries
# removed (the dup entries are verified against their canonical source).
# sha256sum prints "<hash>  <path>"; the sed peels the path for the case test.
while IFS= read -r _line; do
    _p=`sed -n 's/^[0-9a-f]*  \(.*\)$/\1/p' <<EOF_LINE
$_line
EOF_LINE`
    case "$_p" in
        ./binaries/*|./config/*|./custom.sh|./README.md) continue ;;
        ./scripts/enable_hook.sh|./scripts/disable_hook.sh|./scripts/collect_logs.sh) continue ;;
        *) printf '%s\n' "$_line" ;;
    esac
done < "$TMPD/dst.sha" > "$TMPD/dst.shared"

if diff -u "$TMPD/dst.shared" "$TMPD/src.sha" > "$TMPD/diff.shared"; then
    shared_drift=0
else
    shared_drift=1
    cat "$TMPD/diff.shared"
fi

dup_drift=0
printf '%s\n' "$DUP_MAP" > "$TMPD/dup_map"
while IFS= read -r pair; do
    [ -n "$pair" ] || continue
    d=${pair%%:*}; a=${pair##*:}
    if [ ! -f "$DST/$d" ]; then
        echo "payload_sync: nested copy missing: $d" >&2
        dup_drift=1
    elif [ ! -f "$SRC/$a" ]; then
        echo "payload_sync: canonical Addon file missing: $a" >&2
        dup_drift=1
    elif ! cmp -s "$DST/$d" "$SRC/$a"; then
        echo "payload_sync: DUP DRIFT: $d differs from the Addon's $a" >&2
        dup_drift=1
    fi
done < "$TMPD/dup_map"

if [ "$APPLY" = 1 ]; then
    echo "applying: copying the Addon's payload over this repo's copy..."
    find "$DST" -maxdepth 2 -type f -name 'SHA256SUMS.txt' -delete 2>/dev/null || true
    (cd "$SRC" && tar --exclude='./LICENSE' --exclude='./SHA256SUMS.txt' -cf - .) \
        | (cd "$DST" && tar xf -)
    while IFS= read -r pair; do
        [ -n "$pair" ] || continue
        d=${pair%%:*}; a=${pair##*:}
        [ -f "$SRC/$a" ] && cp "$SRC/$a" "$DST/$d"
    done < "$TMPD/dup_map"
    echo "payload_sync: applied. Review and commit the mib-mod/ changes."
    exit 0
fi

if [ "$shared_drift" -eq 0 ] && [ "$dup_drift" -eq 0 ]; then
    echo "payload_sync: OK, no drift."
    exit 0
fi
echo "payload_sync: DRIFT DETECTED. run with --apply to sync from the Addon repo, then commit."
exit 1
