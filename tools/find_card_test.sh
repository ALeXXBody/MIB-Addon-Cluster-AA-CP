#!/bin/sh
# find_card test: the one card/payload locator must find the mod payload on
# every card view/layout combination, WITHOUT a hard-coded card path.
# `mount` is stubbed in the child runner (tools/find_card_child.sh), so no
# cards or units are needed: the fake mount table names the sandbox folder
# as the card, exactly as a unit names its own card mount.
#
#   tools/find_card_test.sh
set -u
REPO=`cd "$(dirname "$0")/.." && pwd`
PAYLOAD="$REPO/mod/cluster_map_aa_greenmenu"

fail=0

run_case()
{
    desc="$1"; card_layout="$2"
    sandbox=`mktemp -d`

    if [ -n "$card_layout" ]; then
        if [ "$card_layout" = modaa ]; then rel="mod/cluster_aa"
        elif [ "$card_layout" = mod ]; then rel="mod/cluster_map_aa_greenmenu"
        elif [ "$card_layout" = modcm ]; then rel="mod/ClusterMap"
        elif [ "$card_layout" = loose ]; then rel="cluster_map_aa_greenmenu"
        else rel="ClusterMap"; fi
        mkdir -p "$sandbox/card/$rel"
        # enough payload that common.sh continues past its completeness check
        cp "$PAYLOAD/enable_hook.sh" "$PAYLOAD/profiles.conf" \
           "$PAYLOAD/gal_dualscreen.conf" "$sandbox/card/$rel/" 2>/dev/null
        cp -r "$PAYLOAD/scripts" "$sandbox/card/$rel/" 2>/dev/null
    else
        mkdir -p "$sandbox/card"
    fi

    # The fake mount table names this sandbox folder as the card: the card
    # "can be anywhere", so the locator must cope with what it is shown.
    RESULT_FILE="$sandbox/result"
    FAKE_TABLE="dev0t12 on $sandbox/card type dos (fat32)" \
         RESULT_FILE="$RESULT_FILE" sh "$REPO/tools/find_card_child.sh"
    out=`cat "$RESULT_FILE" 2>/dev/null || true`

    if [ -z "$card_layout" ]; then
        if [ -z "$out" ]; then
            echo "PASS: $desc (correctly reports no payload: nothing mounted)"
        else
            echo "FAIL: $desc (expected an empty result, got: $out)"; fail=1
        fi
    else
        if printf "%s" "$out" | grep -q "PKG=$sandbox/card/"; then
            echo "PASS: $desc -> $out"
        else
            echo "FAIL: $desc (got: $out)"; fail=1
        fi
    fi
    rm -rf "$sandbox"
}

run_case "local card, shipped cluster_aa"    modaa
run_case "local card, mod layout (legacy)"  mod
run_case "QNET card view, mod layout"       mod
run_case "card on usb view, standalone"     standalone
run_case "local card, loose copy"           loose
run_case "mod folder, standalone inside"    modcm
run_case "card present, payload missing"    ""
echo
[ "$fail" = 0 ] && echo "find_card: all cases PASS" || { echo "find_card: FAILED"; exit 1; }
