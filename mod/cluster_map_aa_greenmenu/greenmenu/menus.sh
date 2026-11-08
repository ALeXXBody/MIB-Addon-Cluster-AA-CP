#!/bin/sh
# menus.sh — THE ONLY script the GEM screen might not find. Everything else
# routes through this one, so a partial/old card copy can never produce
# "Script not found" for a switch (the screen file's other script entries are
# gone in this design; this file + status.sh (classic) are the entry points).
#
#   menus.sh <verb> [arg]
#     install | arm | uninstall | logs | status
#     zoom|navstrip|cardclear|remote|tbt <argument>
#     (the plain upstream screens keep their own scripts too)
HERE=`dirname "$0"`
# The shared view/remount helpers live in the payload's scripts/ folder. The
# dispatcher does not strictly need them, so a missing copy must NEVER kill
# the menu (an unreadable source line exits the whole script: every screen
# entry would silently do nothing).
for _l in "$HERE/lib_app_mount.sh" "$HERE/../scripts/lib_app_mount.sh"; do
    if [ -r "$_l" ]; then . "$_l"; break; fi
done
unset _l

# QUIET GEM CONSOLE (owner rule): what the console shows is the curated
# "story" of the run (about a dozen lines); the whole output goes into
# the diag bundle (diag.txt). Verbs that print a couple of lines by
# design (switches, porting) keep direct output.
run_quiet() {
    _child=$2
    _log=/tmp/cm_menu_$1.log
    trap 2
    trap '' 2
    # optional child argument ($3): zoom up/down, keep_map on/off ...
    if [ -n "$3" ]; then
        sh "$_child" "$3" >$_log 2>&1
    else
        sh "$_child" >$_log 2>&1
    fi
    sh "$HERE/console_summary.sh" "$_log"
    # The owner's first sanity fact: WHICH payload is running. If this line
    # still names an old version after a card refresh, the copy did not land.
    if [ -r "$HERE/../VERSION" ]; then
        _v=
        read _v < "$HERE/../VERSION" 2>/dev/null
        echo "payload on the card: $_v"
    fi
    # -v: the collector prints where the bundle is and whether the card copy
    # really happened (a silent failure there is not evidence, it is a hunt).
    sh "$HERE/diag_collect.sh" append-run "$_log" -v
    # the owner's contract: EVERY entry ends the console with an outcome and
    # the next instruction (run_verdict.sh renders it; no guesswork left)
    sh "$HERE/run_verdict.sh" "$1" "$_log"
}

case "$1" in
    diag)      sh "$HERE/diag_collect.sh" append-run "$2" -v
               sh "$HERE/run_verdict.sh" diag /dev/null ;;
    # Save logs stays DIRECT even when the runner has a bad day: it prints
    # its own Done: line and writes the bundle itself. Evidence must never
    # depend on the mechanism being debugged.
    logs)      sh "$HERE/savelogs.sh"
               sh "$HERE/run_verdict.sh" logs /dev/null ;;

    install)   run_quiet install   "$HERE/install.sh" ;;
    # ARM = the one deliberate "make it live" action, reachable from the GEM
    # itself: no card edit and no PC needed. Nothing else in the payload ever
    # arms the hook on its own.
    arm)       CLUSTERMAP_HOOK_ARMED=1; export CLUSTERMAP_HOOK_ARMED
               run_quiet arm "$HERE/install.sh" ;;
    uninstall) run_quiet uninstall "$HERE/uninstall.sh" ;;
    status)    run_quiet status    "$HERE/status.sh" ;;
    tbt)       run_quiet tbt       "$HERE/switch_to_turn_by_turn.sh" ;;
    zoom)      run_quiet zoom      "$HERE/zoom.sh" "$2" ;;
    navstrip)  run_quiet navstrip  "$HERE/navstrip.sh" "$2" ;;
    cardclear) run_quiet cardclear "$HERE/card_clear.sh" "$2" ;;
    remote)    run_quiet remote    "$HERE/cluster_remote.sh" "$2" ;;
    keep_map)  run_quiet keep_map  "$HERE/keep_map.sh" "$2" ;;
    # two real scripts (on/off), not one script with an argument - the
    # payload carries full_frame_on.sh / full_frame_off.sh and nothing
    # must ever name a file that is not on the card.
    full_frame) case "$2" in
        off)   run_quiet full_frame_off "$HERE/full_frame_off.sh" ;;
        *)     run_quiet full_frame_on  "$HERE/full_frame_on.sh" ;;
    esac ;;

    verify)    run_quiet verify    "$HERE/verify.sh" ;;
    porting)   run_quiet porting   "$HERE/collect_for_porting.sh" ;;
    portfull)  run_quiet portfull  "$HERE/collect_for_porting_full.sh" ;;
    *) echo "menus.sh: unknown verb: $1" >&2; exit 64 ;;
esac
