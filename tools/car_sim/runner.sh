#!/bin/bash
# car_sim/runner.sh — runs the car-simulation pytest suite inside a private
# mount namespace, where the shell scripts being tested see a stand-in unit:
#
#   * /mnt, /net, /fs and /sim are shadowed with tmpfs for the whole run, so
#     the tests can build real view spellings of the unit's partitions and
#     everything evaporates when the namespace exits (host untouched);
#   * /usr/bin (=/bin via Debian's usrmerge) is overlay-mounted with the
#     plain system content as the LOWER layer and tools/car_sim/stubs/* in
#     the UPPER layer, so every script resolves `mount` and `on` FIRST (bin
#     is first in every script's own PATH list) to the sim stubs: `mount`
#     declares CB_MOUNT_TABLE and refuses remounts named in CB_MOUNT_FAIL
#     ("|view|view|"); `on` fails like a console without cross-node caps.
#
# The mount-stub semantics mirror the unit's mount utility: QNX-style
# -uw/-ur flags and table output. Fail shapes: CB_MOUNT_FAIL or a
# probe-blocked view.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
cd "$REPO"
export CAR_SIM_STUB_DIR="$HERE/stubs"

exec unshare -m bash -c '
set -eu
for d in /mnt /net /fs /sim; do
    [ -d "$d" ] || mkdir -p "$d"
    mount -t tmpfs -o size=64m,mode=755 tmpfs "$d"
done
mkdir -p /sim/ovl/up /sim/ovl/work
cp "$CAR_SIM_STUB_DIR/mount" /sim/ovl/up/mount
cp "$CAR_SIM_STUB_DIR/on"    /sim/ovl/up/on
chmod 755 /sim/ovl/up/mount /sim/ovl/up/on
mount -t overlay -o lowerdir=/usr/bin,upperdir=/sim/ovl/up,workdir=/sim/ovl/work overlay /bin
.venv/bin/pytest -q "tools/car_sim" "$@"
'
