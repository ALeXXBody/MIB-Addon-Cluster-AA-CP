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

case "$1" in
    install)   sh "$HERE/install.sh" ;;
    uninstall) sh "$HERE/uninstall.sh" ;;
    status)    sh "$HERE/status.sh" ;;
    logs)      sh "$HERE/savelogs.sh" ;;
    tbt)       sh "$HERE/switch_to_turn_by_turn.sh" ;;
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
