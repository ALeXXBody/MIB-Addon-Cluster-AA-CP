#!/bin/sh

# esd cluster_map_aa_install.sh v0.1.0 (2026-11-04 by mib-cluster-map)
# Fork: install the Android Auto → Virtual Cockpit hook (mib-cluster-map fork)
# from an M.I.B. GEM screen. This does NOT touch persistence bit coding; M.I.B.
# already runs 7 (apps/carp -a) to activate AA/CarPlay/MirrorLink coding.
# Our hook reads the unit's own gal/libautoreceiver, adds a second video sink,
# and pushes the phone's map to the cluster via MOST150.
#
# In M.I.B.'s payload layout the fork lives at mod/cluster_map_aa_greenmenu/
# on the SD card, not at the fork's root: the script below resolves both
# layouts, then runs the fork's enable_hook.sh with the fork's own settings.

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
echo " NOTE: NEVER interrupt the process with -Back- button or removing"
echo "       SD Card!!! Ensure a stable external power supply."
echo ""
echo " This install does NOT patch IFS-ROOT-Stage2, does NOT write FECs and"
echo " does NOT touch M.I.B.'s own CarPlay Maps VC payload. It only adds"
echo " LD_PRELOAD entries to smartphone_integrator.json so that the unit's"
echo " own 'gal' process runs the fork's libgal_hook.so."
echo ""
echo " M.I.B. prerequisites:"
echo "   * Option 7 (CarPlay & Android Auto activation) is coded in already."
echo "     This installer will call it again, it is idempotent."
echo "   * IFS-ROOT-Stage2 is NOT patched by this script."
echo ""

SD=""
for v in /net/mmx/fs/sda0 /net/mmx/fs/sdb0 /fs/sda0 /fs/sdb0; do
	if [ -f "$v/mod/cluster_map_aa_greenmenu/enable_hook.sh" ]; then
		SD=$v; break
	fi
done
if [ -z "$SD" ]; then
	echo "FAIL: mod/cluster_map_aa_greenmenu/enable_hook.sh was not found on SD media."
	trap 2; exit 1
fi

PAYLOAD=$SD/mod/cluster_map_aa_greenmenu

if [ ! -r "$PAYLOAD/enable_hook.sh" ]; then
	echo "FAIL: enable_hook.sh missing in $PAYLOAD"
	trap 2; exit 1
fi

echo "Head unit: MIB-HIGH Harman (MHI2 family for the cluster map hook)"
echo "Running the fork's installer from $PAYLOAD ..."
echo ""

# enable_hook.sh resolves CARD_ROOT from its own location and expects the
# payload layout it ships with (thirdparty/, lsd_jar.sh, gal_dualscreen.conf
# beside it), so it must be run in place, from the payload root.
cd "$PAYLOAD" || { echo "Failed to cd"; trap 2; exit 1; }

# M.I.B. exports $GEM=1 which upsets some of the fork's scripts - clear it.
GEM=
LD_PRELOAD=
export GEM LD_PRELOAD

sh "$PAYLOAD/enable_hook.sh" 2>&1
RESULT=$?
echo ""
if [ "$RESULT" = 0 ]; then
	echo "Cluster map hook: install finished. Press Up / Down / R to reboot."
elif [ "$RESULT" = 2 ]; then
	echo "Cluster map hook: page 2 finished (this is the fork's uninstall/collect mode)."
else
	echo "Cluster map hook: install exit $RESULT — save the fork logs to SD and check."
fi

trap 2
exit $RESULT
