#!/bin/sh
# Fork addition: verify the installed files against the checksum manifest the
# installer left on the unit. Recomputes CRC (cksum) for every line the
# installer recorded and reports PASS / CHANGED per file, so an owner whose
# panel behaves oddly can distinguish a broken install from a settings issue
# without pulling the SD card or reading the hook log.
#
# Manifest line format (written by swdl/update_run.sh):  <path> <crc> <size>
# (cksum's own output minus the path). The loop mirrors that exactly.
. "`dirname "$0"`/common.sh"
MANIFEST=/mnt/app/eso/lib/gal_dualscreen/verify_manifest.txt
echo "Phone map on the digital cluster: verify installed files"
if [ ! -r "$MANIFEST" ]; then
    echo "No checksum manifest found at $MANIFEST"
    echo "(this unit was last installed by a version before the verify script, or"
    echo "the manifest was removed; reinstall from the SD card to recreate it)"
    exit 0
fi
# Portable binary-detect: QNX 6.5's /bin/sh does not understand `command -v`.
CKSUM=""
for c in /usr/bin/cksum /bin/cksum /mnt/app/armle/usr/bin/cksum /opt/bin/cksum cksum; do
    if [ -n "`command -v "$c" 2>/dev/null`" ] || [ -x "$c" ]; then CKSUM="$c"; break; fi
done
if [ -z "$CKSUM" ]; then
    echo "No cksum found anywhere standard on this unit; cannot verify."
    exit 0
fi
FAIL=0; TOTAL=0
while read -r FILEGIVEN WANTSUM WANTSZ; do
    [ -n "$FILEGIVEN" ] || continue
    TOTAL=$((TOTAL+1))
    if [ ! -r "$FILEGIVEN" ]; then
        echo "CHANGED  $FILEGIVEN (missing)"; FAIL=$((FAIL+1)); continue
    fi
    GOT=`cksum "$FILEGIVEN" | awk '{print $1, $2}'`
    if [ "$GOT" = "$WANTSUM $WANTSZ" ]; then
        echo "PASS     $FILEGIVEN"
    else
        echo "CHANGED  $FILEGIVEN (now: $GOT; manifest: $WANTSUM $WANTSZ)"
        FAIL=$((FAIL+1))
    fi
done < "$MANIFEST"
echo
if [ "$FAIL" = 0 ]; then
    echo "All $TOTAL installed files match the manifest."
else
    echo "$FAIL of $TOTAL installed files changed since the install."
    echo "Re-run the update on the SD card to reinstall them, or have a look at"
    echo "docs/Install.md; if the mismatch survives that, post the update_result."
fi
exit 0
