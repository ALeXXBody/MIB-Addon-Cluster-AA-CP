#!/bin/sh
# wheel_tracer.sh - tracer precondition for the steering-wheel listener.
#
# wheel_listen reads the HMI's own DSI tracer stream (telnet 1798 live,
# bluepirat 20991 buffered). The tracer is off by default on this unit
# (owner diag: neither port listens). This switch turns the appenders on
# in the HMI's own traceConfig.properties and enables the keypanel scope
# the wheel needs -- and NOTHING else:
#   - the file is backed up to .orig ONCE (revert restores it byte-equal);
#   - only the file's OWN use.appender key is extended with the two
#     documented appenders (telnet,bluepirat);
#   - only the file's OWN keypanel scope line is enabled: the unit's file
#     carries "#org.dsi.ifc.keypanel.DSIKeyPanel=small|full" commented
#     out, so this flips exactly that line to =full (owner diag
#     proven -- no syntax invented).
# A reboot (power button ~10 s) restarts the HMI and opens the ports.
#
#     wheel_tracer.sh on|off
# Exit 0: switched. 3: nothing to change. Else failed.
HERE=`dirname "$0"`
if [ -r "$HERE/../scripts/lib_app_mount.sh" ]; then
    . "$HERE/../scripts/lib_app_mount.sh"
else
    echo "lib_app_mount.sh missing on the card (re-copy the zip's mod/)" >&2
    exit 1
fi

case "$1" in
    on|off) WANT="$1" ;;
    *) echo "usage: $0 on|off" >&2; exit 2 ;;
esac

# Both spellings seen in the wild (MHI2 lsd/, MH2p top-level).
CFG=""
for _c in "$APP_MOUNT/eso/hmi/lsd/traceConfig.properties" \
         "$APP_MOUNT/eso/hmi/traceConfig.properties"; do
    if [ -r "$_c" ]; then CFG="$_c"; break; fi
done
unset _c
if [ -z "$CFG" ]; then
    echo "No traceConfig.properties under $APP_MOUNT/eso/hmi[/lsd]:"
    echo "the HMI tracer config is not where this firmware keeps it."
    echo "Nothing changed. Send Save-logs: the diag names the hmi tree."
    exit 3
fi
CFG_W=""
MARK=""
_rel=${CFG#$APP_MOUNT}
if [ "$_rel" != "$CFG" ]; then
    CFG_W="$APP_RW$_rel"
    MARK="$APP_RW${_rel%/*}/dsitracer_activated"
fi
unset _rel
if [ -z "$CFG_W" ]; then
    echo "Cannot map $CFG to a writable app view. Nothing changed."
    exit 1
fi

if [ "$WANT" = "off" ]; then
    if [ -r "$CFG.orig" ]; then
        if ! app_mount_rw; then
            echo "Cannot remount the app partition read-write:" >&2
            echo "$APP_LADDER_ERRORS" >&2
            echo "Nothing changed." >&2
            exit 1
        fi
        echo "app: read-write via '$APP_LADDER_FORM'"
        APP_WRITABLE=1
        trap 'if [ -z "${CLUSTERMAP_PARENT_OWNS_MOUNT:-}" ]; then app_mount_finish; fi' 0 1 2 15
        cp "$CFG.orig" "$CFG_W.new" 2>/dev/null &&
        mv "$CFG_W.new" "$CFG" 2>/dev/null || {
            echo "Could not restore $CFG from $CFG.orig. Nothing changed."
            rm -f "$CFG_W.new"; exit 1; }
        rm -f "$MARK" 2>/dev/null || true
        sync
        echo "Wheel tracer: OFF (traceConfig.properties restored from .orig)."
        echo "Reboot to close the tracer ports again."
        exit 0
    fi
    echo "Wheel tracer: OFF (no .orig backup here: nothing was ever changed)."
    echo "Nothing changed."
    exit 3
fi

# on
if command -v netstat >/dev/null 2>&1 && netstat -an 2>/dev/null | grep -qE "[:.]1798 |[:.]20991 "; then
    echo "Wheel tracer: ON already (port 1798/20991 listens)."
    echo "Start Wheel listen ON and press the wheel."
    exit 3
fi
HAVE_LINE=0
if grep -q "^use\.appender=" "$CFG" 2>/dev/null; then HAVE_LINE=1; fi
if [ "$HAVE_LINE" = 0 ]; then
    echo "Wheel tracer: $CFG has no use.appender key, so there is"
    echo "nothing safe to extend (class-scope lines are NOT invented here)."
    echo "--- current file (also in the diag bundle) ---"
    sed -n '1,40p' "$CFG" 2>/dev/null
    echo "Nothing changed. Send Save-logs with this screen."
    exit 3
fi
if ! app_mount_rw; then
    echo "Cannot remount the app partition read-write:" >&2
    echo "$APP_LADDER_ERRORS" >&2
    echo "Nothing changed." >&2
    exit 1
fi
echo "app: read-write via '$APP_LADDER_FORM'"
APP_WRITABLE=1
trap 'if [ -z "${CLUSTERMAP_PARENT_OWNS_MOUNT:-}" ]; then app_mount_finish; fi' 0 1 2 15
if [ ! -r "$CFG.orig" ]; then
    cp "$CFG" "$CFG.orig" 2>/dev/null || {
        echo "Could not back up $CFG to .orig. Nothing changed."; exit 1; }
    echo "Backed up: $CFG.orig"
fi
# Extend the file's OWN use.appender line (last value wins on a duplicate,
# so rewrite the single line instead of appending a second one), and
# enable the keypanel scope the wheel needs. The scope key is NOT
# invented: the unit's own file carries it commented out
# (#org.dsi.ifc.keypanel.DSIKeyPanel=small|full), so this flips exactly
# that line to full and drops its small twin. awk with ~ and sub is
# unit-proven (enable_hook.sh counts env entries this way).
awk '/^use\.appender=/ { app=$0; next }
     /^#?org\.dsi\.ifc\.keypanel\.DSIKeyPanel=/ { have=1; next }
     /^#activate\.extension=/ { print substr($0, 2); have_act=1; next }
     /^activate\.extension=/ { have_act=1; print; next }
     { print }
     END {
         if (app !~ /telnet/) app = app ",telnet"
         if (app !~ /bluepirat/) app = app ",bluepirat"
         sub("=,", "="); print app
         print "org.dsi.ifc.keypanel.DSIKeyPanel=full"
         if (!have_act) print "activate.extension=ctrl,DSIKeyPanelEx" }' "$CFG" > "$CFG_W.new" 2>/dev/null &&
mv "$CFG_W.new" "$CFG" 2>/dev/null || {
    echo "Could not extend use.appender in $CFG. Nothing changed."
    rm -f "$CFG_W.new"; exit 1; }
echo "Appenders now: `grep '^use\.appender=' "$CFG" 2>/dev/null | tail -1`"
echo "Key scope now: `grep '^org\.dsi\.ifc\.keypanel\.DSIKeyPanel=' "$CFG" 2>/dev/null | tail -1`"
echo "Activate now: `grep '^activate\.extension=' "$CFG" 2>/dev/null | tail -1`"
echo "dsitracer_activated by ClusterMap wheel tracer switch" > "$MARK" 2>/dev/null || true
sync
echo "Wheel tracer: ON (reboot now: power button ~10 s)."
echo "After the reboot, Wheel listen ON, then press the wheel:"
echo "rotary zooms the cluster map, short OK cycles presets."
exit 0
