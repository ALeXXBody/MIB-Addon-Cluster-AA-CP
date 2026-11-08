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
    sh "$_child" >$_log 2>&1
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
}

case "$1" in
    diag)      sh "$HERE/diag_collect.sh" append-run "$2" -v ;;
    install)   run_quiet install   "$HERE/install.sh" ;;
    # ARM = the one deliberate "make it live" action, reachable from the GEM
    # itself: no card edit and no PC needed. Nothing else in the payload ever
    # arms the hook on its own.
    arm)       CLUSTERMAP_HOOK_ARMED=1; export CLUSTERMAP_HOOK_ARMED
               run_quiet arm "$HERE/install.sh" ;;
    uninstall) run_quiet uninstall "$HERE/uninstall.sh" ;;
    status)    run_quiet status    "$HERE/status.sh" ;;
    logs)      sh "$HERE/savelogs.sh" ;;
    tbt)       run_quiet tbt       "$HERE/switch_to_turn_by_turn.sh" ;;
    zoom)      sh "$HERE/zoom.sh" "$2" ;;
    navstrip)  sh "$HERE/navstrip.sh" "$2" ;;
    cardclear) sh "$HERE/card_clear.sh" "$2" ;;
    remote)    sh "$HERE/cluster_remote.sh" "$2" ;;
    keep_map)  sh "$HERE/keep_map.sh" "$2" ;;
    full_frame) sh "$HERE/full_frame.sh" "$2" ;;
    verify)    sh "$HERE/verify.sh" ;;
    porting)   sh "$HERE/collect_for_porting.sh" ;;
    portfull)  sh "$HERE/collect_for_porting_full.sh" ;;
    *) echo "menus.sh: unknown verb: $1" >&2; exit 64 ;;
esac
