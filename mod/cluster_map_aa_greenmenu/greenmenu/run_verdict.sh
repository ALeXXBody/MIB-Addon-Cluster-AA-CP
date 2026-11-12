#!/bin/sh
# run_verdict.sh - the END of every ClusterMap run, on the GEM console:
#   == DONE / == STOPPED, then THE NEXT INSTRUCTION.
#   run_verdict.sh <verb> <run-log>
# Exit code: 1 when the run log carries a failure (the runner shows the
# run's ERROR lines), 0 otherwise. Kept brutally simple: one quoted echo
# per line, no case inside a case, no loops except the failure sniff.
VERB="$1"
LOG="$2"

_v=
# v0.7.9: read the payload version from THIS script's own folder, not from
# the process CWD -- the GEM starts scripts with an arbitrary CWD, so
# `./VERSION` (which the car rounds kept printing as "VERSION missing on
# the card") never resolves from a menu press.
_vd=`dirname "$0"`/..
[ -r "$_vd/VERSION" ] && read _v < "$_vd/VERSION" 2>/dev/null
echo "ClusterMap $VERB ran / payload on card: ${_v:-VERSION missing on the card}"

BAD=0
if [ -r "$LOG" ]; then
    if grep -q "^FAIL" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^ERROR" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^CRITICAL" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^MISSING" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "INSTALL_FAILED" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "NOT SUPPORTED" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "Uninstall FAILED" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "Cannot remount" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "Cannot write" "$LOG" 2>/dev/null; then BAD=1; fi
    # v0.7.6: the silent-in-summary failure shapes. Any of these lines means
    # the run stopped before it finished, even when no FAIL/ERROR prefix
    # travelled with it (the v0.7.5 car round hid its reason this way).
    if grep -q "^Could not " "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^Generated .* failed" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^Staged .* failed" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^Persistent recovery copy" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^Active config is already injected" "$LOG" 2>/dev/null; then BAD=1; fi
    if grep -q "^Refusing to install" "$LOG" 2>/dev/null; then BAD=1; fi
fi

BODY=""
case "$VERB" in
    logs)
        BODY="take the SD card home and send me the file: mod/cluster_aa/diag.txt"
        ;;
    install)
        BODY="reboot ONLY if fresh files were staged; existing: geometry already live, next phone session"
        ;;
    arm)
        BODY="reboot the unit (power button ~10 s); the map goes live"
        ;;
    uninstall)
        BODY="reboot the unit (power button ~10 s); the cockpit returns to stock"
        ;;
    tbt)
        BODY="reboot, then select the arrows view on the cockpit"
        ;;
    porting)
        BODY="send me the porting bundle (mod/cluster_aa/porting/, named above)"
        ;;
    portfull)
        BODY="send me the full porting bundle (mod/cluster_aa/porting/, named above)"
        ;;
    position)
        BODY="sent LIVE on the wire; look at the cluster; stamp the look with a photo + Save logs"
        ;;
    hiresen)
        BODY="armed for the NEXT PHONE SESSION (unplug/replug the USB or cycle the phone's AA); no reboot"
        ;;
    idrpump)
        BODY="LIVE - pulsing starts or stops within a second; no reboot"
        ;;
    clustermenu)
        BODY="LIVE - the very next steering wheel press enters/leaves the menu; no reboot"
        ;;
    remotetrace)
        BODY="LIVE - press the wheel (short + long OK, rotary both ways), then Save logs; the diag lists every gesture's own code"
        ;;
    etacard)
        BODY="reconnect the phone: the card takes its new edge; stamp the look with a photo + Save logs"
        ;;
    status)
        BODY="nothing required - stay or leave (Back), your call"
        ;;
    verify)
        BODY="nothing required - stay or leave (Back), your call"
        ;;
    diag)
        BODY="nothing required - stay or leave (Back), your call"
        ;;
    full_frame_on)
        BODY="lands when the phone re-streams (replug the USB); the std look reaches back with sharper-map OFF"
        ;;
    full_frame_off)
        BODY="lands when the phone re-streams (replug the USB); ON brings the full-frame back"
        ;;
    undeclared)
        BODY="leave the menu (Back), the setting is live on the unit"
        ;;
    off)
        BODY="leave the menu (Back), the setting is live on the unit"
        ;;
    *)
        # zoom on/off, cardclear, navstrip, remote, keep_map: live right away
        BODY="leave the menu (Back), the setting is live on the unit"
        ;;
esac

if [ "$BAD" = 1 ]; then
    echo "== STOPPED - the reason follows (run log: diag.txt)"
    echo "Next: send me the diag file (Save logs -> mod/cluster_aa/diag.txt)"
    exit 1
fi
echo "== DONE"
echo "Next: $BODY"
exit 0
