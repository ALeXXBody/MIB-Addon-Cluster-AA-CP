#!/bin/sh
# Fork: run a real unit binary (default: dmdt) on actual QNX 6.5 under QEMU,
# using luka-dev's BSP boot pieces (startup-virt, libstartup.a, devc-serdebug,
# u-boot.bin) and the fork's own mkifs build file that packs the unit's
# binaries and its dependency closure.
#
# On this host, the podman *container* path is blocked by nested-cgroup
# restrictions, so the mkifs/linker stage runs through a chroot into an
# extracted copy of the toolchain image (see README.md for the one-time
# setup:  podman build  +  podman save  +  extract to $QNX_CHROOT). The
# QEMU boot itself runs on the bare host and does not need the chroot.
#
# Requirements:
#   tests/emul/qnxifs/       staged unit binaries  (git-ignored, see README)
#   qnx65-airv7 toolchain    cloned at $QNX_UPSTREAM (../qnx65 by default)
#   $QNX_CHROOT              unpacked toolchain image, with mkifs inside
#   qemu-system-arm          host package
#
# Usage: run_unit_dmdt.sh [args...]     args = dmdt's arguments (default gs)
HERE=$(cd "$(dirname "$0")" && pwd)
QNX_UPSTREAM="${QNX_UPSTREAM:-$(dirname "$HERE")/../../qnx65}"
IFS_UNIT="$HERE/qnxifs"                          # unit files (git-ignored)
IFS_BUILD="$HERE/qnxifs-unit.build"
CHROOT="${QNX_CHROOT:-/tmp/opencode/mib2/qnx-image-root}"
export QNX_TARGET="$QNX_UPSTREAM/sdp/target/qnx6"
export QNX_HOST="$QNX_UPSTREAM/sdp/host/linux/x86"
export QNX_CONFIGURATION="$QNX_UPSTREAM/sdp/etc/qnx"
: "${QEMU_RUN_SECS:=45}"
: "${QEMU_TIMEOUT:=75}"

for f in "$CHROOT/opt/qnx650/host/linux/x86/usr/bin/mkifs" \
         "$QNX_UPSTREAM/tests/qemu/u-boot.bin" \
         "$IFS_UNIT/eso/bin/apps/dmdt"; do
    if [ ! -e "$f" ]; then
        echo "Missing $f" >&2
        echo "See tests/emul/README.md for the one-time setup." >&2
        exit 2
    fi
done

# stage the IFS into the chroot's /w layer (mkifs resolves host-relative paths)
mkdir -p "$CHROOT/w"
if [ "${1:-}" = "(none)" ]; then : > "$CHROOT/w/dmdt_args_from_host"; else printf '%s' "${*:-gs}" > "$CHROOT/w/dmdt_args_from_host"; fi
cp "$IFS_BUILD" "$CHROOT/w/build-unit.build"
rm -rf "$CHROOT/w/eso" "$CHROOT/w/lib" "$CHROOT/w/config" "$CHROOT/w/dmdtgo" "$CHROOT/w/rundmdt"
cp -a "$IFS_UNIT/." "$CHROOT/w/"
cp "$QNX_UPSTREAM/tests/qemu/startup-virt" "$CHROOT/w/"
cp "$QNX_UPSTREAM/tests/qemu/libstartup.a" "$CHROOT/w/"
cp "$QNX_UPSTREAM/tests/qemu/devc-serdebug" "$CHROOT/w/"
cp "$QNX_TARGET/armle-v7/boot/sys/procnto-smp" "$CHROOT/w/" 2>/dev/null
cp "$QNX_TARGET/armle-v7/lib/libc.so.3" "$CHROOT/w/" 2>/dev/null
cp "$QNX_TARGET/armle-v7/lib/libm.so.2" "$CHROOT/w/"
cp "$QNX_UPSTREAM/sdp/target/qnx6/armle-v7/lib/libsocket.so.3" "$CHROOT/w/"

echo "== mkifs (chroot, image = localhost/qnx65-armv7-toolchain:8.5)" >&2
chroot "$CHROOT" /bin/sh -c '
  export QNX_CONFIGURATION=/opt/qnx650/etc/qnx
  export QNX_TARGET=/opt/qnx650/target/qnx6
  export QNX_HOST=/opt/qnx650/host/linux/x86
  export PATH=/opt/qnx650/host/linux/x86/usr/bin:$PATH
  export LD_LIBRARY_PATH=/opt/qnx650/host/linux/x86/usr/lib:$LD_LIBRARY_PATH
  cd /w
  mkifs build-unit.build ifs.bin
' | tail -4
if [ ! -s "$CHROOT/w/ifs.bin" ]; then
    echo "mkifs produced no image" >&2
    exit 1
fi

echo "== boot (qemu-system-arm virt)" >&2
mkdir -p "$HERE/tmp/fat"
mv "$CHROOT/w/ifs.bin" "$HERE/tmp/fat/ifs.bin"
LOG="$HERE/tmp/qemu.log"
( sleep 4; printf '\n'; sleep 2
  printf 'virtio scan\n'; sleep 2
  printf 'fatload virtio 0:1 0x40200000 ifs.bin\n'; sleep 3
  printf 'go 0x40200000\n'; sleep "${QEMU_RUN_SECS}" ) | \
  timeout "${QEMU_TIMEOUT}" qemu-system-arm -M virt -m 256 -cpu cortex-a15 \
    -bios "$QNX_UPSTREAM/tests/qemu/u-boot.bin" \
    -drive file=fat:rw:"$HERE/tmp/fat",format=raw,media=disk \
    -display none -serial stdio > "$LOG" 2>&1 || true

echo "=== filtered output ==="
awk ' /@@QNXRUN-START@@/ { sub(/.*@@QNXRUN-START@@/, ""); inside = 1 }
      /@@QNXRUN-END@@/   { sub(/@@QNXRUN-END@@.*/, ""); inside = 0 }
      inside && length($0) { print }' "$LOG"

mkdir -p "$HERE/fixtures"
[ -s "$LOG" ] && cp "$LOG" "$HERE/fixtures/qemu_dmdt_$(date +%s).log"
exit 0
