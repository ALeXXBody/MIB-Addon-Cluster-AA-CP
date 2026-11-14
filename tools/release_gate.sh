#!/bin/sh
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
# contract, the FULL car-simulation suite, and audit_wiring ALL GREEN.
#
# This script IS the rule in executable form. tools/build_release.sh
# refuses versioned builds when this gate is red; CI runs the static
# half on every push. The full suite needs a mount namespace, so it is
# enforced locally here — never skipped, never "green enough".
# ============================================================================
set -eu
cd "$(dirname "$0")/.."

FAIL=0
step() { echo "== gate: $1"; }
pass() { echo "   PASS $1"; }
fail() { echo "   FAIL: $1"; FAIL=1; }

step "shell syntax (every .sh)"
if (find mod tools -name '*.sh' | while IFS= read -r f; do
        sh -n "$f" || echo "SYNTAX FAIL: $f"
    done | grep -q .); then fail "sh -n"; else pass "sh -n"; fi

step "payload manifest"
if tools/check_manifest.sh >/dev/null 2>&1; then pass "manifest"; else fail "manifest"; fi

step "screen files parse"
if tools/check_gem_esd.sh >/dev/null 2>&1; then pass "gem esd"; else fail "gem esd"; fi

step "card locator"
if tools/find_card_test.sh >/dev/null 2>&1; then pass "find_card"; else fail "find_card"; fi

step "portability (no bare missing-tool usage)"
if tools/gem_portable_check.sh >/dev/null 2>&1; then pass "portable"; else fail "portable"; fi

step "release contract (armed zip, unarmed repo, no stale diag)"
if tools/check_release_build.sh >/dev/null 2>&1; then pass "contract"; else fail "contract"; fi

step "full car-simulation suite"
if bash tools/venv_test.sh >/dev/null 2>&1; then pass "car-sim"; else fail "car-sim"; fi

step "wiring audit"
if sh tools/audit_wiring.sh "gate" >/dev/null 2>&1; then pass "audit"; else fail "audit"; fi

echo ""
if [ "$FAIL" = 0 ]; then
    echo "RELEASE GATE: ALL GREEN - this checkout may ship."
    exit 0
fi
echo "RELEASE GATE: RED - DO NOT RELEASE. Fix the failures above first." >&2
exit 1
