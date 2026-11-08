#!/bin/sh
# menus.sh — THE ONLY script the GEM screen might not find. Everything else
# routes through this one, so a partial/old card copy can never produce
# "Script not found" for a switch (the screen file's other script entries are
# gone in this design; this file + status.sh (classic) are the entry points).
#
#   menus.sh <verb> [arg]
#     install | uninstall | logs | status
#     zoom|navstrip|cardclear|remote|tbt <argument>
#     (the plain upstream screens keep their own scripts too)
HERE=`dirname "$0"`
. "$HERE/lib_app_mount.sh" 2>/dev/null || . "$HERE/lib_app_mount.sh"

# QUIET GEM CONSOLE (owner rule): what the console shows is the curated
# "story" of the run (about a dozen lines); the whole output goes into the
# card's diag bundle (diag.txt). Verbs that print a couple of lines by
# design (switches, porting) keep direct output.
run_quiet() {
    _child=$2
    _log=/tmp/cm_menu_$1.log
    trap 2
    trap '' 2
    sh "$_child" >$_log 2>&1
    sh "$HERE/console_summary.sh" "$_log"
    echo "(full log on the card: mod/cluster_map_aa_greenmenu/diag.txt)"
    sh "$HERE/diag_collect.sh" append-run "$_log"
    echo "(the diag bundle holds the full run and the unit state)"
}

case "$1" in
    diag)      sh "$HERE/diag_collect.sh" append-run "$2"; echo "diag bundle written: mod/cluster_map_aa_greenmenu/diag.txt"; ;;
    install)   run_quiet install   "$HERE/install.sh" ;;
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
