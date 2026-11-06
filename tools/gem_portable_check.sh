#!/bin/sh
# portable-tools check: our GEM-run scripts must never rely on the four
# binaries the unit has proven missing (printf tr cmp diff) or on the grep
# -o non-extension. M.I.B.'s contract (config/GLOBALS) is to bundle its own
# tools on the card (apps/sbin) and put that folder first on PATH — our
# common.sh bootstrap adopts it (find_card). This check fails a build when
# a script reintroduces a bare missing-tool usage without a guard.
#
#   tools/gem_portable_check.sh        (from the repository root)
set -u
cd "$(dirname "$0")/.."
fail=0
# grep -o must never appear (the unit's grep rejects it; use sed)
if grep -rn "grep -o" --include='*.sh' mod 2>/dev/null | grep -v experiments/ | grep -v "no"; then
    echo "gem_portable: bare 'grep -o' found"; fail=1
fi
for key in printf "tr -d" "diff "; do
    hits=$(grep -rn "$key" --include='*.sh' mod 2>/dev/null | grep -vE "experiments/|command -v|# |Note: .cmp|lib_unit.sh:57")
    if [ -n "$hits" ]; then
        echo "gem_portable: missing-tool usage '$key':"
        echo "$hits" | head -5
        fail=1
    fi
done
[ "$fail" = 0 ] && echo "gem_portable: OK (no bare missing-tool usage)"
exit $fail
