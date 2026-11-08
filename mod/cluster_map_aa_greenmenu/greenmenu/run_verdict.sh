#!/bin/sh
# run_verdict.sh - the END of every ClusterMap run, on the GEM console:
#   == DONE / == STOPPED, then THE NEXT INSTRUCTION. The owner asked for
#   an explicit end + what to do next on every entry; a "silent ok" state
#   was never more than a guess from the story lines.
#   run_verdict.sh <verb> <run-log>
VERB="$1"; LOG="$2"
BAD=0
# POSIX-safe failure sniff: no -E, no alternation (portable shells + the
# unit's grep differ); each verdict keyword is its own probe.
if [ -r "$LOG" ]; then
    for _pat in "^FAIL" "^ERROR" "^CRITICAL" "^MISSING" \
                "INSTALL_FAILED" "NOT SUPPORTED" "Uninstall FAILED" \
                "Cannot remount" "Cannot write"; do
        if grep -q "$_pat" "$LOG" 2>/dev/null; then BAD=1; break; fi
    done
fi
case "$VERB" in
    logs)       BODY="take the SD card home and send me the file: mod/cluster_aa/diag.txt" ;;
    install)    BODY="reboot the unit (power button ~10 s), then switch the cockpit to the map view" ;;
    arm)        BODY="reboot the unit (power button ~10 s); the map goes live" ;;
    uninstall)  BODY="reboot the unit (power button ~10 s); the cockpit returns to stock" ;;
    tbt)        BODY="reboot, then select the arrows view on the cockpit" ;;
    full_frame*|zoom*|cardclear*|navstrip*|remote*|keep_map*)
                BODY="leave the menu (Back): the setting is live on the unit" ;;
    porting|portfull)
                BODY="send me the bundle: mod/cluster_aa/porting/ (named above)" ;;
    status|verify|diag)
                BODY="nothing required - stay or leave (Back), your call" ;;
    *)          BODY="leave the menu (Back)" ;;
esac
if [ "$BAD" = 1 ]; then
    echo "== STOPPED - the reason follows (run log: diag.txt)"
    echo "Next: send me the diag file (Save logs -> mod/cluster_aa/diag.txt)"
else
    echo "== DONE"
    echo "Next: $BODY"
fi
# the exit code is the runner's switch for showing the failure story
exit ${BAD}
