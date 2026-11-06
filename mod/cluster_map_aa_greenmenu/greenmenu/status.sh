#!/bin/sh
. "`dirname "$0"`/common.sh"
# View-aware reads: the same unit file can only be addressable under one of
# several partition-view spellings from this console node (MHI2 prints the
# QNET FQDN form in mount); pick whichever spelling actually resolves.
_unitsys() {
    for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
        [ -r "$_v/$1" ] && { echo "$_v/$1"; return 0; }
    done
    echo "/mnt/system/$1"
}
_unitapp() {
    for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
        [ -r "$_v/$1" ] && { echo "$_v/$1"; return 0; }
    done
    echo "/mnt/app/$1"
}
CONFIG=`_unitsys etc/eso/production/smartphone_integrator.json`
LSD=`_unitapp eso/hmi/lsd/lsd.sh`
echo "Phone map on the digital cluster: status"
echo "Package folder: $PKG"
echo "Firmware train: $TRAIN"
if train_supported; then echo "  supported: yes ($SUPPORT_NOTE)"; else echo "  supported: NO, needs $SUPPORTED_TRAIN ($SUPPORT_NOTE)"; fi
if grep -q 'libgal_hook.so' "$CONFIG" 2>/dev/null; then echo "Hook: installed"; else echo "Hook: not installed"; fi
if [ -f "`_unitapp eso/lib/gal_dualscreen/libgal_hook.so`" ]; then echo "  library: present"; else echo "  library: missing"; fi
if [ -f "`_unitapp navigation/stream-player`" ]; then echo "  player: present"; else echo "  player: missing"; fi
if grep -q 'libcarplay_cluster.so' "$CONFIG" 2>/dev/null; then
    cp_dim=`sed -n 's/.*"ALTSCREEN111_WIDTH=\([0-9]*\)", "ALTSCREEN111_HEIGHT=\([0-9]*\)".*/\1x\2/p' "$CONFIG"`
    echo "CarPlay map: installed, $cp_dim"
    if [ -r /tmp/mibr-carplay111.state ]; then echo "  CarPlay cluster stream: `cat /tmp/mibr-carplay111.state`"; else echo "  CarPlay cluster stream: none yet (connect an iPhone)"; fi
else
    _apfile=`_unitapp eso/lib/libairplay.so`
    a=`wc -c < "$_apfile" 2>/dev/null | sed 's/ //g'`
    if [ "$a" = 703688 ]; then echo "CarPlay map: not installed (this unit's CarPlay library is supported)"; else echo "CarPlay map: not installed (CarPlay library ${a:-missing} bytes; supported: 703688)"; fi
fi
if sh "$PKG/lsd_jar.sh" loaded NavActiveIgnore.jar; then echo "NavActiveIgnore: loaded (required)"
elif sh "$PKG/lsd_jar.sh" loaded CarPlayNavigationPatch.jar; then echo "NavActiveIgnore: loaded as CarPlay's CarPlayNavigationPatch.jar (same patch)"
else echo "NavActiveIgnore: not loaded (Install adds it on tested firmware)"; fi
if sh "$PKG/lsd_jar.sh" loaded VCAndroidAuto.jar; then echo "Turn-by-turn arrows (VCAndroidAuto.jar): loaded. Installing the map turns this off."; else echo "Turn-by-turn arrows (VCAndroidAuto.jar): not loaded"; fi
echo "Java patch lines:"
grep -n 'Xbootclasspath/p' "$LSD" 2>/dev/null | sed 's|.*/p:||; s|\$BASE_DIR/lsd/jars/||g; s|"$||; s|^|  |'
if [ -r /tmp/gal_dualscreen.log ]; then
    echo "Last hook events:"
    grep -E "event=(init |firmware.verify|secondary.register|focus.state|player.spawn|focus.loss)" /tmp/gal_dualscreen.log | tail -6 | sed -e 's/^gal_dualscreen //' -e 's/^\(.\{110\}\).*/\1/'
else
    echo "No hook log yet (connect a phone after rebooting)."
fi
exit 0
