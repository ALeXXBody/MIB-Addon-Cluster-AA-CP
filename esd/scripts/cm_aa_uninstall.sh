#!/bin/sh

# esd cluster_map_aa_uninstall.sh v0.1.0 (2026-11-04 by mib-cluster-map-tiguan)
# Fork: uninstall mib-cluster-map AA→VC hook via M.I.B.'s GEM shell.
# Delegates to the fork's own uninstaller (keeps the same state as the
# fork's GEM "uninstall" screen) — after this the HU restores the stock
# gal ster configuration.
#
# Does not touch M.I.B.'s CarPlay Maps VC payload.

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

SD=""
for v in /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0; do
	if [ -f "$v/mod/cluster_map_aa_greenmenu/scripts/disable_hook.sh" ]; then
		SD=$v; break
	fi
done
if [ -z "$SD" ]; then
	echo "FAIL: mod/cluster_map_aa_greenmenu/scripts/disable_hook.sh was not found on SD media."
	trap 2; exit 1
fi

FORK_SCRIPTS=$SD/mod/cluster_map_aa_greenmenu/scripts
cd "$FORK_SCRIPTS" || { echo "Failed to cd"; trap 2; exit 1; }

# Drop M.I.B.'s GEM flag so our uninstaller is in charge of its own flow.
GEM=
LD_PRELOAD=
export GEM LD_PRELOAD

echo "Running the fork's uninstaller from $FORK_SCRIPTS ..."
sh "$FORK_SCRIPTS/disable_hook.sh" 2>&1
RESULT=$?
echo ""
if [ "$RESULT" = 0 ]; then
	echo "Cluster map hook: uninstalled successfully."
elif [ "$RESULT" = 2 ]; then
	echo "Cluster map hook: page/step finished — see the fork's script output above."
else
	echo "Cluster map hook: uninstall exit $RESULT — see docs/Install.md for recovery steps."
fi

trap 2
exit $RESULT
