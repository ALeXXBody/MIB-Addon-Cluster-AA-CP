#!/bin/sh
# audit_wiring.sh - the END-TO-END wiring audit for a release tag:
#   tools/audit_wiring.sh v0.6.1
# Verifies that every GEM press lands somewhere real: screen entries are
# bare paths that exist, wrappers reach the dispatcher, dispatcher verbs
# run scripts that exist, every key a GEM switch writes is a key the
# shipped binaries READ, the verdict chain works live, and the manifest
# + release contract still hold on a real build. Additive by design.
set -u
cd "$(cd "$(dirname "$0")/.." && pwd)"
PAYLOAD=mod/cluster_map_aa_greenmenu
GREEN=$PAYLOAD/greenmenu
PASS=1
ok()   { echo "  PASS  $1"; }
fail() { echo "  FAIL  $1"; PASS=0; }

echo "== 1. the GEM screen names a wrapper per entry, and every wrapper exists"
tpl=$GREEN/cluster-map.template.esd
built=$GREEN/cluster-map.esd
sed -n 's/.*"@GREENMENU@\([^"]*\)".*/\1/p' "$tpl" | sort -u > /tmp/audit_tpl
sed -n 's#.*"/net/mmx/fs/sda0/mod/cluster_aa/\([^"]*\)".*#\1#p' "$built" |
    sed 's|^greenmenu/||' | sort -u > /tmp/audit_built
if cmp -s /tmp/audit_tpl /tmp/audit_built; then
    ok "template and built screen agree"
else
    fail "template/built entries differ"
fi
n_wrappers=`ls $GREEN/gem/*.sh 2>/dev/null | wc -l`
n_entries=`grep -c . /tmp/audit_built || true`
[ "$n_wrappers" -gt 0 ] && [ "$n_entries" -gt 0 ] &&
    ok "wrappers: $n_wrappers, screen entries: $n_entries" ||
    fail "no wrappers/entries"

echo "== 2. every entry is a bare script path (no arguments in the value)"
arg_entries=`sed -n 's/^    value   sys 1 0x0100 "\([^"]*\.sh[^"]*\)"/\1/p' \
    $GREEN/cluster-map.esd | grep -c ' '` || true
if [ "${arg_entries:-0}" -gt 0 ]; then
    fail "the built screen still carries dispatcher arguments"
else
    ok "all values are bare script paths"
fi

echo "== 3. every wrapper -> dispatcher verb -> existing child script"
verb_ok=1
for w in $GREEN/gem/*.sh; do
    v=`sed -n 's/.*menus\.sh" \([^" ]*\).*/\1/p' "$w" | head -1`
    if [ -z "$v" ]; then
        fail "wrapper `basename "$w"` does not name a dispatcher"; verb_ok=0; continue
    fi
    if ! grep -q "^    ${v})" $GREEN/menus.sh; then
        fail "wrapper `basename "$w"` -> verb '$v' unknown to menus.sh"; verb_ok=0; continue
    fi
    children=`sed -n "/^    ${v})/,/;;/p" $GREEN/menus.sh \
        | grep -o '\\$HERE/[A-Za-z0-9_./-]*\.sh' | sed 's|.*/||'`
    for nf in $children; do
        [ -f "$GREEN/$nf" ] || { fail "verb $v runs $nf: MISSING"; verb_ok=0; }
    done
done
[ "$verb_ok" = 1 ] && ok "all wrapper paths resolve (children checked)"

echo "== 4. every key a GEM switch writes has a binary consumer"
union=`{ strings $PAYLOAD/libgal_hook.so; strings $PAYLOAD/stream-player; }`
missing=0
for key in GAL_PLAYER_WINDOW GAL_SECONDARY_DPI GAL_SECONDARY_INSETS \
           GAL_SECONDARY_MARGINS GAL_SECONDARY_PIXEL_ASPECT_RATIO_E4 \
           GAL_CLUSTER_REMOTE GAL_PLAYER_ZOOM_E4 \
           GAL_KEEP_MAP GAL_SECONDARY_HIRESEN GAL_IDR_PUMP \
           GAL_REMOTE_TRACE GAL_CLUSTER_MENU; do
    case "$union" in
        *"$key"*) : ;;
        *)  fail "no binary reads $key"; missing=1 ;;
    esac
done
[ "$missing" = 0 ] && ok "every GEM-writable key has a consumer (hook/player)"

echo "== 5. the verdict chain: live parse + exit contract"
sh -n $GREEN/run_verdict.sh || fail "run_verdict.sh does not parse"
printf 'FAIL: probe\n' > /tmp/audit.log
sh $GREEN/run_verdict.sh install /tmp/audit.log >/dev/null 2>&1
rc5=$?
[ "$rc5" = 1 ] && ok "verdict exit contract (fail -> 1)" ||
    fail "run_verdict must exit 1 on a failing log"
printf 'clean run\n' > /tmp/audit.log
sh $GREEN/run_verdict.sh install /tmp/audit.log >/dev/null 2>&1
rc5=$?
[ "$rc5" = 0 ] && ok "verdict exit contract (clean -> 0)" ||
    fail "run_verdict exits 1 on a clean log (rc=$rc5)"
rm -f /tmp/audit.log

echo "== 6. every GEM-reachable script parses"
shfail=0
for f in $PAYLOAD/*.sh $GREEN/*.sh $GREEN/gem/*.sh $PAYLOAD/scripts/*.sh; do
    sh -n "$f" || { fail "syntax: $f"; shfail=1; }
done
[ "$shfail" = 0 ] && ok "all scripts parse"

echo "== 7. manifest + release contract + static gates"
tools/check_manifest.sh 2>/dev/null | grep -q OK &&
    ok "manifest matches the shipped file set" || fail "manifest stale"
out=`sh tools/check_release_build.sh 2>&1 || true`
echo "$out" | grep -q OK && ok "release contract (armed zip, unarmed repo)" || fail "release contract"
tools/check_gem_esd.sh >/dev/null 2>&1 && ok "screen files parse" || fail "screen parse"
tools/gem_portable_check.sh >/dev/null 2>&1 && ok "no bare missing-tools usage" || fail "portability regress"
out=`tools/find_card_test.sh 2>&1 || true`
echo "$out" | grep -q "all cases PASS" && ok "find_card across layouts" || fail "find_card"

echo "== 8. the press -> capture -> chain (diag/card) wiring"
grep -q 'run_quiet' $GREEN/menus.sh && ok "runner in use" || fail "presses bypass the runner"
grep -q 'diag_collect.sh.*append-run' $GREEN/menus.sh &&
    ok "every press captured into the bundle" || fail "capture missing"
grep -q 'run_verdict.sh' $GREEN/menus.sh && ok "verdict tail wired" || fail "verdict tail missing"
grep -q 'CARDOUT="\$_h/diag.txt"' $GREEN/diag_collect.sh &&
    ok "card truth recorded" || fail "card truth unrecorded"
grep -q 'GAL_PLAYER_WINDOW' $GREEN/diag_collect.sh &&
    ok "the bundle carries the tuning facts" || fail "tuning facts missing"

if [ "$PASS" = 1 ]; then
    echo "audit_wiring: ALL GREEN (${1:-local})"
    exit 0
fi
echo "audit_wiring: FAILURES ABOVE (${1:-local})"
exit 1
