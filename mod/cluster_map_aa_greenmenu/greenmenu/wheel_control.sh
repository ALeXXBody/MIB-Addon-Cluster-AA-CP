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

case "$1" in
    on|off) WANT="$1" ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

if [ "$WANT" = "off" ]; then
    sh "$HERE/wheel_listen.sh" off
    L=$?
    sh "$HERE/wheel_tracer.sh" off
    T=$?
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
