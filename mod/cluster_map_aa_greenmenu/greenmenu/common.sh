# Sourced by the green menu entries. Finds the package folder, on whichever
# card or USB stick these scripts run from, makes it writable and checks the
# firmware train.
PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH
export PATH

# ---------------------------------------------------------------------------
# M.I.B.'s own contract (config/GLOBALS): the unit lacks printf/tr/cmp/diff,
# and its M.I.B. card ships app/sbin/{sed,awk,cut,tee,sha1sum,dd,gzip}. Our
# payload runs from that same card, so find_card PATCHES PATH in front with
# the card's tools folder the moment it locates it. Nothing later in this
# file or the scripts that source it needs to re-derive the tools.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# find_card: THE card/payload locator. Every script that sources this file
# gets VOLUME (the card root) and PKG (the payload folder) out of it —
# nothing else in the code base may hardcode a card path.
#
# What it copes with (owner requirements: the card can be anywhere):
#   * the card under ANY of these views:
#       local views:        /fs/sda0 /fs/sdb0 /fs/usb0_0 ... (plus whatever
#                           `mount` says is actually mounted there)
#       QNET network views: /net/<node>/fs/sdaN (card owned by another core)
#   * the payload in any of these places:
#       <card>/mod/cluster_map_aa_greenmenu   (M.I.B. mod layout, this Addon)
#       <card>/ClusterMap                     (fork's standalone SWDL card)
#       <card>/mod/ClusterMap                 (standalone under a mod folder)
#       <card>/cluster_map_aa_greenmenu       (loose copy at the card root)
#
# Mount-table-derived candidates come first, then the fixed list as a
# fallback (covers a mount table quirks). The unit's GEM console can run on
# either QNX core; the mount table of THIS core is tried first, and its
# /fs/* storage views are what this node can remount.
# ---------------------------------------------------------------------------
find_card()
{
    _cands=""
    VOLUME=""; PKG=""

    # 1. every storage-looking mount point this node knows about
    for _p in `mount 2>/dev/null | sed -n "s|^.* on \(/[^ ]*\) .*|\1|p"`; do
        _cands="$_cands $_p"
    done
    # 2. the fixed fallback list (a mount table that does not show /fs/*)
    _cands="$_cands /fs/sda0 /fs/sdb0 /fs/sda1 /fs/sdd0 /fs/usb0_0 /fs/usb1_0 \
           /net/mmx/fs/sda0 /net/mmx/fs/sdb0 \
           /net/mmx.mibhigh.net/fs/sda0 /net/mmx.mibhigh.net/fs/sdb0"

    for _v in $_cands; do
        [ -d "$_v" ] || continue
        for _rel in mod/cluster_map_aa_greenmenu ClusterMap cluster_map_aa_greenmenu mod/ClusterMap; do
            if [ -f "$_v/$_rel/enable_hook.sh" ]; then
                VOLUME=`cd "$_v" 2>/dev/null && pwd`
                PKG="$VOLUME/$_rel"
                # M.I.B.'s bundled tools on this card: put them FIRST on
                # PATH (M.I.B.'s config/GLOBALS contract). Nothing later in
                # the run needs to re-derive them.
                for _t in "${_v}/apps/sbin" "${_v}/tools/sbin" \
                          /net/mmx/fs/sda0/apps/sbin /net/mmx/fs/sdb0/apps/sbin \
                          /net/mmx.mibhigh.net/fs/sda0/apps/sbin; do
                    if [ -f "${_t}/sed" ] || [ -f "${_t}/sha1sum" ]; then
                        PATH="$_t:$PATH"; export PATH
                        break
                    fi
                done
                return 0
            fi
        done
    done
    return 1
}

find_card || {
    # Last resort for nodes where the mount table names nothing (some GEM
    # consoles): the network views with the modern node name spellings.
    for _v in /fs/sda0 /fs/sdb0 /net/mmx/fs/sda0 /net/mmx/fs/sdb0 \
              /net/mmx.mibhigh.net/fs/sda0 /net/mmx.mibhigh.net/fs/sdb0; do
        if [ -d "$_v" ]; then
            for _rel in mod/cluster_map_aa_greenmenu ClusterMap cluster_map_aa_greenmenu mod/ClusterMap; do
                if [ -f "$_v/$_rel/enable_hook.sh" ]; then
                    VOLUME="$_v"; PKG="$_v/$_rel"; break
                fi
            done
        fi
        [ -n "$PKG" ] && break
    done
}

if [ -z "$PKG" ]; then
    echo "ClusterMap folder not found on any mounted card, stick or USB media."
    echo "(This script looked at the unit's mount table and every known card"
    echo " view, for mod/cluster_map_aa_greenmenu and ClusterMap layouts.)"
    exit 0
fi
# The card root is VOLUME now (a real mount point), never the payload's
# parent: in the M.I.B. mod layout that parent is the card's mod FOLDER,
# which cannot be remounted (a GEM run printed "Can't remount
# /net/mmx/fs/sda0/mod" for exactly this reason).

# The GEM console can run on a core whose view of the SD card is a QNET
# mount of another core's device (MIB2.5 High shows this card as
# /net/<node>/dev/sda0t12 on /fs/sda0). A remount may then have to reach
# the device/node in a specific form; try each one and SHOW the real
# error for every attempt, so the diagnosis is measured, not guessed.
CARD_LINE=`mount 2>/dev/null | grep " on /fs/sda0 " | head -1`
CARD_DEV=`echo "$CARD_LINE" | sed -n "s|^\([^ ]*\) on .*|\1|p"`
CARD_NODE=`echo "$CARD_LINE" | sed -n "s|^/net/\([^/]*\)/dev/.* on .*|\1|p"`
[ -n "$CARD_LINE" ] && echo "Card mounted as: $CARD_LINE"
# Never a guessed slot: the mount point comes from the same mount-table
# line that identified the card (the M.I.B. GEM console prints exactly
# "/net/mmx.mibhigh.net/dev/sda0t12 on /fs/sda0" / "/fs/sda0" style lines).
CARD_MNT=`echo "$CARD_LINE" | sed -n "s|.* on \(/[^ ]*\) .*|\1|p"`
[ -n "$CARD_MNT" ] || CARD_MNT="$VOLUME"
mount -uw "$CARD_MNT" 2>&1 | head -1 || true
if [ -n "$CARD_NODE" ]; then
	mount -uw "$CARD_DEV" "$CARD_MNT" 2>&1 | head -1 || true
	on -f "$CARD_NODE" mount -uw "$CARD_MNT" 2>&1 | head -1 || true
	# both node spellings: the shorthand name and the FQDN form
	on -f mmx /bin/mount -uw "$CARD_MNT" 2>&1 | head -1 || true
	on -f mmx.mibhigh.net /bin/mount -uw "$CARD_MNT" 2>&1 | head -1 || true
fi
mount -uw "$VOLUME" 2>&1 | head -1 || true
# Probe it (non-fatal: Status and other read-only entries still work fine).
if ! mkdir "$VOLUME/.clustermap_rw_probe" 2>/dev/null; then
    echo ""
    echo "PROBLEM: the SD card is READ-ONLY to the unit ($VOLUME)."
    echo "  1. The LOCK slider on the SD adapter must be in the unlocked"
    echo "     (up) position."
    echo "  2. The card must be formatted FAT32, not exFAT/NTFS."
    echo "  3. If both are fine, run chkdsk /f on the card in a PC: a dirty"
    echo "     volume flag makes the unit mount the card read-only."
    echo ""
    echo "For diagnosis, the unit's mount state:"
    echo "MOUNT_TABLE_START"
    mount 2>/dev/null | grep -i -e sd0 -e sda0 -e sdb0 || echo "(no sda0/sdb0 line found)"
    echo "MOUNT_TABLE_END"
    echo ""
fi
rmdir "$VOLUME/.clustermap_rw_probe" 2>/dev/null
# A failed "." ends the shell, and with it the whole install, so check first.
if [ ! -r "$PKG/scripts/lib_unit.sh" ] || [ ! -r "$PKG/profiles.conf" ]; then
    echo "This ClusterMap folder is incomplete: unpack the release zip again."
    exit 0
fi
. "$PKG/scripts/lib_unit.sh"

TRAIN=unknown
for f in /net/rcc/dev/shmem/version.txt /dev/shmem/version.txt; do
    if [ -r "$f" ]; then
        TRAIN=`grep "Current train" "$f" | sed 's/Current train = //' | sed -e 's|["'"'"']||g' | sed 's/\r//'`
        break
    fi
done

# Whether the map can be installed. profiles.conf holds the car-tested trains;
# any other train counts when its gal is a build we have a profile for, which
# profile_check reads from the file. The hook checks the same addresses itself
# when it loads and leaves Android Auto stock on any mismatch, so this gate only
# exists to stop an install that cannot work.
SUPPORT_NOTE=
# The two phone libraries this project attaches to, and where units keep them.
#
# Android Auto: MIB2.5 High units call it libautoreceiver.so and keep it in
# /mnt/app/eso/lib, with a second copy at /eso/lib. The older VWG11
# generation links libautoreceiver_qnx.so.1 beside libaoa-lite instead
# (issue #28: Vladimir's K3342 gal names it in its DT_NEEDED), so a unit with
# no libautoreceiver.so has not necessarily no receiver.
#
# CarPlay: libairplay.so, which the CarPlay hook attaches to by exported
# symbol name. Collected for the same reason as the receiver -- it is what a
# port has to be checked against, and asking for it afterwards costs a round
# trip (issue #10, US P3662, whose build differs from the tested one).
LIB_DIRS="/mnt/app/eso/lib /eso/lib /mnt/app/armle/lib /mnt/app/usr/lib /mnt/app/root/lib-target"
RECEIVER_NAMES="libautoreceiver.so libautoreceiver_qnx.so.1"
AIRPLAY_NAMES="libairplay.so"
# First readable file among the names given, in the library folders.
lib_path()
{
    for d in $LIB_DIRS; do
        for n in "$@"; do
            if [ -r "$d/$n" ]; then echo "$d/$n"; return 0; fi
        done
    done
    return 1
}
receiver_path() { lib_path $RECEIVER_NAMES; }
airplay_path()  { lib_path $AIRPLAY_NAMES; }
train_supported()
{
    # VWG11 before K3342: not supported, update first (#39; install.sh).
    case "$TRAIN" in
        *_VWG11_S*) SUPPORT_NOTE="not supported: update to MHI2_ER_VWG11_K3342_1_AIO_MU1427 first (#39)"; return 1 ;;
    esac
    # PROBE_OUT is also what tells us about a unit that is not supported.
    unit_gal_check "$PKG" || PROBE_OUT=
    if train_has "$PKG/profiles.conf" "$TRAIN" map; then
        SUPPORT_NOTE="tested firmware"
        return 0
    fi
    if [ -n "$PROBE_MATCH" ]; then
        SUPPORT_NOTE="this train is not listed, but its Android Auto program is the $PROBE_MATCH build"
        return 0
    fi
    g=`wc -c < /mnt/app/eso/bin/apps/gal 2>/dev/null | sed 's/ //g'`
    RECEIVER_FOUND=`receiver_path`
    r=`wc -c < "$RECEIVER_FOUND" 2>/dev/null | sed 's/ //g'`
    # A trial profile for this train in the settings file (as find_profile.py
    # prints it): installed for testing. The hook checks the real addresses
    # when it loads and does nothing if they differ.
    p=`sed -n 's/^GAL_PROFILE_TRIAL=\([^:]*\):.*/\1/p' "$PKG/gal_dualscreen.conf" 2>/dev/null | head -1`
    if [ -n "$p" ]; then
        case "$TRAIN" in
            *${p}*) SUPPORT_NOTE="UNTESTED firmware, with the trial profile $p from gal_dualscreen.conf"; return 0 ;;
        esac
    fi
    if [ -z "$RECEIVER_FOUND" ]; then
        SUPPORT_NOTE="no Android Auto receiver library found (gal $g bytes)"
    else
        SUPPORT_NOTE="different Android Auto files (gal $g, `echo "$RECEIVER_FOUND" | sed 's|.*/||'` $r bytes)"
    fi
    return 1
}

# Firmware where adi961's turn-arrows jar (VCAndroidAuto.jar) is known to work
# ("arrows" in profiles.conf). The jar replaces Java classes of the unit's
# interface; on a firmware it does not fit, the centre screen may not start, so
# it is never installed on any other train.
tbt_supported() { train_has "$PKG/profiles.conf" "$TRAIN" arrows; }

# What a run that installs nothing has still left behind, said plainly: #10
# found B201A00 and a sporadic U10CF00 logged at the minute of the SD update,
# before anything of this project ran.
nothing_installed()
{
    echo "Nothing was installed. The green menu screen was added, which Uninstall"
    echo "removes. A software update from SD can also log fault B201A00 (Check"
    echo "Software Version Management) in the head unit; see docs/Install.md."
}

# The head unit family, from the train name, for messages only.
case "$TRAIN" in
    MHI2Q_*) FAMILY="Audi MIB2 High, Qualcomm (MHI2Q)" ;;
    MHI2_*)  FAMILY="Harman MIB2 / MIB2.5 High (MHI2)" ;;
    MST2_*)  FAMILY="MIB2 Standard (Technisat/Preh, MST2)" ;;
    *)       FAMILY="unknown" ;;
esac
