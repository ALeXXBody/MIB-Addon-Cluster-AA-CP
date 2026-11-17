#!/usr/bin/env bash
# ============================================================================
# RELEASE RULE — owner-mandated, HIGHEST PRIORITY (2026-11-14).
#
#   NOTHING SHIPS WITHOUT PROOF.
#
# Every implementation or change must be properly tested BEFORE any
# release. Concretely: a versioned release (tools/build_release.sh vX.Y.Z,
# a v* tag push, a GitHub release) is FORBIDDEN unless every check below
# passes in the same checkout: syntax of every shell script, payload
# manifest, screen files, card locator, portability, the release
# contract, the FULL car-simulation suite, and audit wiring ALL GREEN.
#
# This script IS the rule in executable form. tools/build_release.sh
# refuses versioned builds when this gate is red; CI runs it on every
# versioned build. The full sim suite needs a mount namespace (root on
# CI); every step's log is kept, and on failure the tail is printed, so
# a red gate always names its reason instead of hiding it.
# ============================================================================
set -eu
cd "$(dirname "$0")/.."

FAIL=0
LOGDIR=/tmp/gate-logs
rm -rf "$LOGDIR"; mkdir -p "$LOGDIR"

run() {
    local id="$1"; shift
    echo "== gate: $id"
    if "$@" >"$LOGDIR/$id.log" 2>&1; then
        echo "   PASS $id"
    else
        echo "   FAIL: $id (tail of $LOGDIR/$id.log follows):"
        tail -25 "$LOGDIR/$id.log" | sed 's/^/   | /'
        FAIL=1
    fi
}

run syntax bash -c 'fail=0; while IFS= read -r -d "" f; do sh -n "$f" || { echo "SYNTAX FAIL: $f"; fail=1; }; done < <(find mod tools -name "*.sh" -print0); exit $fail'
run manifest tools/check_manifest.sh
run screens tools/check_gem_esd.sh
run findcard tools/find_card_test.sh
run portable tools/gem_portable_check.sh
run contract tools/check_release_build.sh
run wheelunit bash -c 'cc -Wall -Wextra -I sources/src sources/tests/wheel_autostart_test.c sources/src/wheel_autostart.c -o /tmp/gate_wlstart && /tmp/gate_wlstart'
run carsim bash tools/venv_test.sh
run audit sh tools/audit_wiring.sh local

echo ""
if [ "$FAIL" = 0 ]; then
    echo "RELEASE GATE: ALL GREEN - this checkout may ship."
    exit 0
fi
echo "RELEASE GATE: RED - DO NOT RELEASE. Full logs in $LOGDIR." >&2
exit 1
