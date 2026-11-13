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

echo "== 9. switch runtime-file formats agree with the hook's readers"
# The hook reads these exact byte shapes; a switch that writes KEY=VALUE into
# them arms nothing (the v0.7.4 bug). Assert every switch uses the bare value.
rtfail=0
for f in $GREEN/cluster_remote.sh $GREEN/remote_trace.sh $GREEN/clustermenu.sh \
         $GREEN/hiresen.sh $GREEN/idrpump.sh $GREEN/position.sh; do
    [ -f "$f" ] || continue
    if grep -q 'live_write .*GAL_RUNTIME_DIR' "$f"; then
        : # uses the shared helper
    else
        fail "`basename $f` does not route its runtime write through live_write"; rtfail=1
    fi
    code=`sed '/^[[:space:]]*#/d' "$f"`
    if echo "$code" | grep -q '/tmp/gal_'; then
        fail "`basename $f` hardcodes a /tmp runtime path"; rtfail=1
    fi
done
[ "$rtfail" = 0 ] && ok "every switch writes the bare value through \$GAL_RUNTIME_DIR"

# runtime default must be /tmp (the hook's own literal path)
grep -q 'GAL_RUNTIME_DIR="\${GAL_RUNTIME_DIR:-/tmp}"' $PAYLOAD/scripts/lib_app_mount.sh &&
    ok "runtime directory defaults to /tmp (matches the hook)" ||
    fail "runtime directory default is not /tmp"

# binary carries the tap + build marker. Every silent-failure path must
# have a named line: the tap filter, the gate, the menu event, the write
# failure lines, the parsed trace. If any is missing, a future failure
# there goes unexplained again.
for needle in 'event=remote.tap' 'event=cluster.remote.live' \
              'event=cluster.remote.gate result=closed' '/tmp/gal_remote' 'event=remote.trace parse' \
              'event=remote.tap result=filtered' 'event=cluster.menu.event' 'result=failed reason=cannot-write' \
              'event=aap.out'; do
    if strings $PAYLOAD/libgal_hook.so | grep -qF "$needle"; then :; else
        fail "shipped hook lacks '$needle'"; rtfail=1
    fi
done
[ "$rtfail" = 0 ] && ok "shipped hook carries the tap + build marker"

echo "== 10. no silent-death shapes (the v0.7.19 class)"
# At most one EXIT-trap setter per file, never cleared mid-file: a second
# setter silently replaced the v0.7.7 safety net and the unit kept dying
# mute. The enable/disable traps must report (their non-zero exits are
# always real failures; helper scripts' non-zero exits can be routine, so
# theirs stay cleanup-only and their callers translate rc into words).
# Every bare statement-start single-command substitution under set -e must
# carry its own `||` guard (QNX sh exits the whole script on a failed
# one); pipes, guards and substitutions inside conditions are proven safe
# on the car and must not trip the gate.
silentfail=0
# lib_app_mount.sh is a sourced library (no set -e, no trap of its own):
# it runs inside its callers' traps, but its substitutions still execute
# under the caller's set -e, so they are checked in the second loop.
for f in $PAYLOAD/enable_hook.sh \
         $PAYLOAD/disable_hook.sh $PAYLOAD/turn_by_turn.sh \
         $PAYLOAD/scripts/turn_by_turn.sh $PAYLOAD/lsd_jar.sh \
         $PAYLOAD/scripts/lsd_jar.sh; do
    nset=`grep -c '^trap [^-]' "$f" 2>/dev/null || true`
    if [ "$nset" -gt 1 ]; then
        fail "`basename $f`: $nset EXIT-trap setters (at most 1)"; silentfail=1
    fi
    if grep -q '^trap -' "$f" 2>/dev/null; then
        fail "`basename $f` clears its EXIT trap mid-file"; silentfail=1
    fi
done
for f in "enable_hook.sh:FAIL: enable_hook stopped" \
         "disable_hook.sh:FAIL: disable_hook stopped"; do
    n=${f%%:*}; needle=${f#*:}
    if ! grep -qF "$needle" "$PAYLOAD/$n" 2>/dev/null; then
        fail "$n finish() never reports its rc"; silentfail=1
    fi
done
# precise per-line check: VAR=`cmd` at statement start, single command
# (no pipe inside), unguarded (no || after it). Piped/guarded/conditional
# forms are safe and must not trip the gate.
for f in $PAYLOAD/scripts/lib_app_mount.sh $PAYLOAD/enable_hook.sh \
         $PAYLOAD/disable_hook.sh $PAYLOAD/turn_by_turn.sh \
         $PAYLOAD/scripts/turn_by_turn.sh $PAYLOAD/lsd_jar.sh \
         $PAYLOAD/scripts/lsd_jar.sh; do
    awk '!/^#/ {
        line=$0
        if (match(line, /^[ \t]*[A-Za-z_][A-Za-z0-9_]*=`[^`]*`/)) {
            span=substr(line, RSTART, RLENGTH)
            rest=substr(line, RSTART+RLENGTH)
            if (index(span, "|") == 0 && index(rest, "||") == 0)
                print FILENAME":"FNR": "line
        }
    }' "$f" 2>/dev/null || true
done > /tmp/audit_bare_subst
if [ -s /tmp/audit_bare_subst ]; then
    while IFS= read -r ln; do fail "bare substitution: $ln"; silentfail=1; done < /tmp/audit_bare_subst
fi
rm -f /tmp/audit_bare_subst
[ "$silentfail" = 0 ] && ok "traps single+reporting; no bare substitutions under set -e"

if [ "$PASS" = 1 ]; then
    echo "audit_wiring: ALL GREEN (${1:-local})"
    exit 0
fi
echo "audit_wiring: FAILURES ABOVE (${1:-local})"
exit 1
