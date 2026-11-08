#!/bin/bash
# venv_test.sh — the offline "is it working properly" gate.
#
# Creates (once) a Python venv with pytest, then runs:
#   1. the repo's own shell checks (manifest, GEM screen, find_card, tools
#      portability, full .sh syntax sweep),
#   2. tools/car_sim/ — the car-simulation suite executed inside a private
#      mount namespace where /mnt, /net, /fs, /sim are tmpfs shadows, so the
#      tests can build REAL view spellings of the unit (read-only and
#      read-write, FQDN QNET forms included) without touching this host.
#
# Everything the suite creates evaporates when the namespace exits.
set -eu
cd "$(cd "$(dirname "$0")/.." && pwd)"

VENV=.venv
if [ ! -x "$VENV/bin/pytest" ]; then
    echo "== creating venv (python3 -m venv .venv; pip install pytest)"
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q pytest
fi

echo "== repo shell checks"
tools/check_manifest.sh
tools/check_gem_esd.sh
tools/find_card_test.sh
tools/gem_portable_check.sh
tools/check_release_build.sh
for f in $(find mod tools -name '*.sh') tools/car_sim/*.sh; do
    sh -n "$f"
done
echo "== shell checks OK"

echo "== car simulation suite (private mount namespace)"
exec tools/car_sim/runner.sh "$@"
