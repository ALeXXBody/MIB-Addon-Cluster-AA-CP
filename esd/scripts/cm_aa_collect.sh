#!/bin/sh

# esd cluster_map_aa_collect.sh v0.1.0 (2026-11-04 by mib-cluster-map)
# Fork: save mib-cluster-map logs to the SD card via M.I.B.'s GEM shell.
# Delegates to the fork's own collect script (the upstream HU-side wrapper
# used in tests, `collect_logs.sh`), which writes a diagnostic bundle to
# /log/... and syncs to the SD slot it finds.

if [ -f /net/rcc/dev/shmem/reboot.mib ] || [ -f /net/rcc/dev/shmem/backup.mib ] || [ -f /net/rcc/dev/shmem/flash.mib ]; then
	echo "Some process is already running in background, don't interrupt!"
	exit 0
fi

trap '' 2
export GEM=1
echo -ne "M.I.B. - More Incredible Bash - "
cat /net/mmx/fs/sda0/VERSION 2>/dev/null
echo "Android Auto Map on the digital cluster (mib-cluster-map fork)"
echo ""

SD=""
for v in /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0; do
	if [ -f "$v/mod/cluster_map_aa_greenmenu/collect_logs.sh" ]; then
		SD=$v; break
	fi
done
if [ -z "$SD" ]; then
	echo "FAIL: mod/cluster_map_aa_greenmenu/collect_logs.sh was not found on SD media."
	trap 2; exit 1
fi

PAYLOAD=$SD/mod/cluster_map_aa_greenmenu
cd "$PAYLOAD" || { echo "Failed to cd"; trap 2; exit 1; }

GEM=
LD_PRELOAD=
export GEM LD_PRELOAD

echo "Collecting fork logs into the SD card..."
sh "$PAYLOAD/collect_logs.sh" 2>&1
RESULT=$?
echo ""
if [ "$RESULT" = 0 ]; then
	echo "Fork logs collected successfully."
else
	echo "Fork logs collection exit $RESULT."
fi

trap 2
exit $RESULT
