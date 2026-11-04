#!/bin/sh

# esd cluster_map_aa_status.sh v0.1.0 (2026-11-04 by mib-cluster-map-tiguan)
# Fork: status of the Android Auto → Virtual Cockpit hook (mib-cluster-map).
#
# Runs our fork's hook_status.sh from the fork's own "mod" folder on the SD
# card (M.I.B. convention: everything runs from SD1, nothing is installed
# outside /net/mmx/fs/sda0/... for the payload).

if [ -f /net/rcc/dev/shmem/reboot.mib ] || [ -f /net/rcc/dev/shmem/backup.mib ] || [ -f /net/rcc/dev/shmem/flash.mib ]; then
	echo "Some process is already running in background, don't interrupt!"
	exit 0
fi

trap '' 2
export GEM=1
echo -ne "M.I.B. - More Incredible Bash - "
cat /net/mmx/fs/sda0/VERSION 2>/dev/null
echo "Android Auto Map on the digital cluster (mib-cluster-map-tiguan fork)"
echo ""

SDSUB=""
for v in /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0; do
	if [ -f "$v/mod/cluster_map_aa_greenmenu/enable_hook.sh" ]; then
		SDSUB=$v
		break
	fi
done
if [ -z "$SDSUB" ]; then
	echo "FAIL: mod/cluster_map_aa_greenmenu was not found on SD media."
	echo "Put the mib-cluster-map-tiguan mod folder at mod/cluster_map_aa_greenmenu on the SD card, then retry."
	echo ""
	echo "See https://github.com/ALeXXBody/mib-cluster-map-tiguan (docs/mib-mod/)."
	trap 2; exit 1
fi

echo "Status (from mib-cluster-map-tiguan):"
echo ""
LD_LIBRARY_PATH=":" OK=1 sh "$SDSUB/mod/cluster_map_aa_greenmenu/scripts/hook_status.sh" 2>&1 || { echo "looks like the hook isn't installed here"; }
echo ""

trap 2
exit 0
