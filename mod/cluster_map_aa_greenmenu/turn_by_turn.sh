#!/bin/sh
# The turn-by-turn arrows jar (adi961's VCAndroidAuto.jar) and the cluster map
# cannot both be active: with the jar loaded, the cluster goes blank when a
# route starts. This script switches the jar on and off through lsd_jar.sh.
#
#   turn_by_turn.sh remove    take its line out (done by the map installer)
#   turn_by_turn.sh restore   put it back, only if "remove" took it out
#   turn_by_turn.sh install   copy the bundled jar if needed and add its line
#   turn_by_turn.sh uninstall take it out again, only if "install" added it
#
# Reboot afterwards.
PATH=/proc/boot:/bin:/usr/bin:/usr/sbin:/sbin:/mnt/app/armle/bin:/mnt/app/armle/sbin:/mnt/app/armle/usr/bin:/mnt/app/armle/usr/sbin:$PATH
export PATH
set -eu

HERE=`cd "\`dirname "$0"\`" && pwd` || { echo "Cannot resolve the payload root" >&2; exit 1; }
NAME=VCAndroidAuto.jar
# View-aware markers: the console may resolve the app partition only through
# the FQDN spelling. Probe every view for an existing marker; write through
# the first writable one.
_marker_find() {
    for _v in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
        if [ -f "$_v/eso/hmi/lsd/$1" ]; then echo "$_v/eso/hmi/lsd/$1"; return 0; fi
    done
    echo "/mnt/app/eso/hmi/lsd/$1"
    return 1
}
_marker_write() {
    # $1 = set|clear, $2 = filename. Writes through the first view that
    # accepts a file write; falls back to a bare remount attempt per view.
    for _v in /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app /mnt/app; do
        [ -d "$_v/eso/hmi/lsd" ] || continue
        if ( : > "$_v/eso/hmi/lsd/.clustermap_tbt_probe" ) 2>/dev/null; then
            rm -f "$_v/eso/hmi/lsd/.clustermap_tbt_probe" 2>/dev/null
            if [ "$1" = set ]; then : > "$_v/eso/hmi/lsd/$2" 2>/dev/null || continue
            else rm -f "$_v/eso/hmi/lsd/$2" 2>/dev/null; fi
            return 0
        fi
        mount -uw "$_v" 2>/dev/null || continue
        if ( : > "$_v/eso/hmi/lsd/.clustermap_tbt_probe" ) 2>/dev/null; then
            rm -f "$_v/eso/hmi/lsd/.clustermap_tbt_probe" 2>/dev/null
            if [ "$1" = set ]; then : > "$_v/eso/hmi/lsd/$2" 2>/dev/null || { mount -ur "$_v" 2>/dev/null; continue; }
            else rm -f "$_v/eso/hmi/lsd/$2" 2>/dev/null; fi
            mount -ur "$_v" 2>/dev/null || true
            return 0
        fi
        mount -ur "$_v" 2>/dev/null || true
    done
    return 1
}
MARKER=`_marker_find .aacluster_tbt_removed || true`
ADDED=`_marker_find .aacluster_tbt_added || true`
mark() { _marker_write "$1" .aacluster_tbt_removed || true; MARKER=`_marker_find .aacluster_tbt_removed || true`; }
mark_added() { _marker_write "$1" .aacluster_tbt_added || true; ADDED=`_marker_find .aacluster_tbt_added || true`; }
_sys_cfg() {
    for _v in /mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system; do
        [ -r "$_v/etc/eso/production/smartphone_integrator.json" ] && { echo "$_v/etc/eso/production/smartphone_integrator.json"; return 0; }
    done
    echo "/mnt/system/etc/eso/production/smartphone_integrator.json"
    return 1
}

case "${1:-}" in
    remove)
        if sh "$HERE/lsd_jar.sh" loaded $NAME; then
            sh "$HERE/lsd_jar.sh" remove $NAME
            mark set
        else
            echo "$NAME is not loaded; nothing to remove."
        fi ;;
    restore)
        if [ -f "$MARKER" ]; then
            sh "$HERE/lsd_jar.sh" add $NAME "$HERE/thirdparty/$NAME"
            mark clear
        else
            echo "The installer did not remove a turn-by-turn jar on this unit; nothing to restore."
        fi ;;
    install)
        _cfg=`_sys_cfg || true`
        if grep -q 'libgal_hook.so' "$_cfg" 2>/dev/null; then
            echo "The cluster map is installed. Uninstall it first; the two cannot run together." >&2; exit 1
        fi
        if sh "$HERE/lsd_jar.sh" loaded $NAME; then
            echo "$NAME is already loaded; nothing to add."
        else
            sh "$HERE/lsd_jar.sh" add $NAME "$HERE/thirdparty/$NAME"
            mark_added set
        fi
        mark clear ;;
    uninstall)
        if [ -f "$ADDED" ]; then
            sh "$HERE/lsd_jar.sh" remove $NAME
            mark_added clear
        else
            echo "This package did not add the turn-by-turn jar; it was left alone."
        fi ;;
    *) echo "usage: $0 remove|restore|install|uninstall" >&2; exit 2 ;;
esac
echo "Reboot the unit to apply."
