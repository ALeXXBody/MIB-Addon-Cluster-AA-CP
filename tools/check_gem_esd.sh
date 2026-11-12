#!/bin/sh
# CI + local check: the green-menu screen file(s) must parse. Checks:
#   1. every `screen <name> <parent>` line has exactly two name fields
#   2. a screen's parent is either a known top-level parent (=>M.I.B.<=,
#      main, Main) or declared in this same file
#   3. every `script` value with a payload path /net/mmx/fs/sda0/mod/<the
#      mod folder>/... actually exists in this repository
#
#   tools/check_gem_esd.sh [file ...]        (from the repository root)
set -eu
cd "$(dirname "$0")/.."

if [ $# -gt 0 ]; then
    FILES="$*"
else
    FILES=$(find mod docs -name '*.esd' 2>/dev/null || true)
fi
if [ -z "${FILES-}" ]; then
    echo "check_gem_esd: no .esd files found (skipping)"
    exit 0
fi

fail=0
for f in $FILES; do
    if ! grep -q '^screen' "$f"; then
        echo "check_gem_esd: $f declares no screens (skipping)"
        continue
    fi
    # 1. screen lines: 'screen <name> <parent>'
    if [ "$(grep '^screen' "$f" | awk 'NF!=3' | wc -l)" != 0 ]; then
        echo "check_gem_esd: $f: screen lines must be 'screen <name> <parent>'"
        grep '^screen' "$f" | awk 'NF!=3' | sed 's/^/  /'
        fail=1
    fi
    # 2. parents (exact 2nd-field match, no prefix match)
    for p in $(grep '^screen' "$f" | awk '{print $3}' | sort -u); do
        case "$p" in
            "=>M.I.B.<="|main|Main) continue ;;
        esac
        if ! grep '^screen ' "$f" | awk '{print $2}' | grep -qx "$p"; then
            echo "check_gem_esd: $f: parent '$p' is not declared in this file"
            fail=1
        fi
    done
    # 3. script paths: resolve @GREENMENU@ to the payload dir first so the
    #    template's 40+ wrapper entries are validated too (previously only
    #    /net/…mod/… values were checked, i.e. the template was invisible).
    #    Every "/net/…*.sh" value is checked; esd/scripts/reboot.sh is the
    #    one allowed external (M.I.B.'s own tree).
    _tmp=$(mktemp)
    sed 's|@GREENMENU@|/net/mmx/fs/sda0/mod/cluster_aa/greenmenu/|g' "$f" > "$_tmp"
    for v in $(grep -o '"/net/[^"]*\.sh[^"]*"' "$_tmp" | tr -d '"' | sed 's/ .*//' | sort -u); do
        case "$v" in */esd/scripts/*) continue ;; esac
        rel=${v#/net/mmx/fs/sda0/}
        # the release renames the payload folder; in the repository it lives
        # under the historical name, so resolve the release name first.
        case "$rel" in
            mod/cluster_aa/*) rel=${rel#mod/cluster_aa/}; rel=mod/cluster_map_aa_greenmenu/$rel ;;
        esac
        if [ ! -f "$rel" ]; then
            echo "check_gem_esd: $f references missing file: $v"
            fail=1
        fi
    done
    rm -f "$_tmp"
done

if [ "$fail" = 0 ]; then
    echo "check_gem_esd: OK"
else
    echo "check_gem_esd: FAILED"
fi
exit $fail
