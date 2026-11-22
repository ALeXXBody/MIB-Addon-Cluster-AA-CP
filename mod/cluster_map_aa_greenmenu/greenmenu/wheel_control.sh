#!/bin/sh
# wheel_control.sh - the whole wheel path in one press.
#
# Fresh installs since v0.7.26 already did both parts automatically
# (tracer appenders + staged listener, hook autostart at boot), so this
# is the repair switch for a dead wheel, and the way back out:
#   on:  ensure the tracer appenders, then start the listener.
#   off: stop the listener, then revert the tracer to its .orig.
# Exit 0: done. 3: nothing to change. Else failed.
HERE=`dirname "$0"`
# PKG resolution: wheel_control installs the MFW capture jar from the card
# payload (thirdparty/), so it needs the same card locator every other
# greenmenu switch uses. Without it $PKG was empty and the jar check
# looked at a relative path that never exists (found by the sim test).
if [ -r "$HERE/common.sh" ]; then
    . "$HERE/common.sh"
fi
find_card >/dev/null 2>&1 || true
[ -n "$PKG" ] || PKG=`cd "$HERE/.." && pwd`

case "$1" in
    on|off) WANT="$1" ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ "$WANT" = "off" ]; then
    sh "$HERE/wheel_listen.sh" off
    L=$?
    sh "$HERE/wheel_tracer.sh" off
    T=$?
    # Remove the MFW capture jar the ON press installed (only ours to
    # remove: a jar omonob's own installer put there stays).
    if sh "$PKG/lsd_jar.sh" remove CarPlayClusterControls.jar 2>/dev/null; then
        for _wv in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
            rm -f "$_wv/eso/hmi/lsd/.aacluster_wheeljar_added" \
                  "$_wv/eso/hmi/lsd/jars/CarPlayClusterControls.jar" 2>/dev/null || true
        done
        echo "MFW capture jar removed."
        unset _wv
    fi
    if [ "$L" = 3 ] && [ "$T" = 3 ]; then
        echo "Wheel control: already fully off. Nothing changed."
        exit 3
    fi
    if [ "$L" != 0 ] && [ "$L" != 3 ]; then exit "$L"; fi
    if [ "$T" != 0 ] && [ "$T" != 3 ]; then exit "$T"; fi
    echo "Wheel control: OFF (listener stopped, tracer reverted)."
    exit 0
fi

sh "$HERE/wheel_tracer.sh" on
T=$?
sh "$HERE/wheel_listen.sh" on
L=$?
# The omonob CarPlayClusterControls.jar (GPL-3.0, shipped unmodified in
# thirdparty/) is the wheel path that ACTUALLY works on this unit: the
# production HMI never runs the DSI tracer endpoints (owner diag, v0.7.41:
# activation line active, HMI restarted, ports still silent), but the jar's
# bootclasspath-patched DSIKeyPanelDispatcher receives the MFW keys in the
# Java layer and sends them as plain-ASCII datagrams our listener reads on
# 127.0.0.1:7032/7033. Same install mechanism as NavActiveIgnore (proven
# loaded on this unit), marked, and removed again on OFF.
JAR="$PKG/thirdparty/CarPlayClusterControls.jar"
if [ -r "$JAR" ]; then
    if sh "$PKG/lsd_jar.sh" add CarPlayClusterControls.jar "$JAR"; then
        WJ=0
        for _wv in /mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app; do
            if [ -f "$_wv/eso/hmi/lsd/.aacluster_wheeljar_added" ] || \
               ( mount -uw "$_wv" 2>/dev/null && { : > "$_wv/eso/hmi/lsd/.aacluster_wheeljar_added"; mount -ur "$_wv" 2>/dev/null || true; } ); then
                WJ=1
                echo "MFW capture jar installed (one reboot: the dispatcher sends the wheel to the listener)."
                break
            fi
        done
        unset _wv WJ
    else
        echo "WARNING: could not install the MFW capture jar; the tracer path stays as configured." >&2
    fi
else
    echo "WARNING: thirdparty/CarPlayClusterControls.jar missing on the card - the wheel stays on the tracer path only." >&2
fi
if [ "$L" != 0 ]; then
    echo "Wheel control: the listener did not start (see above)."
    exit "$L"
fi
if command -v netstat >/dev/null 2>&1 && netstat -an 2>/dev/null | grep -qE "[:.]1798 |[:.]20991 "; then
    echo "Wheel control: ON. Press the wheel: rotary zooms, OK presses switch card/strip."
else
    echo "Wheel control: ON. One reboot (power button ~10 s), then press the wheel."
fi
if [ "$T" != 0 ] && [ "$T" != 3 ]; then exit "$T"; fi
exit 0
