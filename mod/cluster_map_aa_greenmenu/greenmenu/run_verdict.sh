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
[ -r "VERSION" ] && read _v < "VERSION" 2>/dev/null
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
fi

BODY=""
case "$VERB" in
    logs)
        BODY="take the SD card home and send me the file: mod/cluster_aa/diag.txt"
        ;;
    install)
        BODY="reboot the unit (power button ~10 s), then switch the cockpit to the map view"
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
        BODY="reconnect the phone: the content box sits at the new insets (step shown above); stamp the look with a photo + Save logs"
        ;;
    hiresen)
        BODY="reboot the unit (power button ~10 s); the trial key lands at the next gal start; press Hi-res OFF to undo"
        ;;
    idrpump)
        BODY="reboot the unit (power button ~10 s); the pump lands at the next gal start; press Sharpness pump OFF to undo"
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
        BODY="reboot the unit (power button ~10 s) - the sharper-map switch lands then"
        ;;
    full_frame_off)
        BODY="reboot the unit (power button ~10 s) - the sharper-map switch lands then"
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
