#!/bin/sh
# release_guide.sh PREV_TAG TAG - the "how do I apply this version" guide,
# computed from the real file diff between the two tags. Verdict rules:
#   * anything under mod/**          -> card update (merge mod/)
#   * files the installer COPIES onto the unit (the hook .so, the settings
#     copy, the screen template, the installer-side helpers) or the screen
#     generator itself -> ONE MORE GEM CLICK (re-run Run /mod/custom.sh)
#     and a reboot
#   * docs-only                      -> "no card update needed"
# Output: an APPLY section ready for the release notes and the zip HOW-TO.
set -u
PREV=${1:?"release_guide: previous tag missing"}
TAG=${2:?"release_guide: tag missing"}
cd "$(cd "$(dirname "$0")/.." && pwd)"

FILES=$(git diff --name-only "$PREV" "$TAG" | LC_ALL=C sort)
if [ -z "$FILES" ]; then
    echo "## APPLY $TAG"
    echo "No payload files changed since $PREV (docs only): the installed map"
    echo "keeps running as it was; nothing to copy."
    exit 0
fi

UNIT_COPIES=" libgal_hook.so libdmdt_flush.so stream-player gal_dualscreen.conf profile_check profiles.conf lsd_jar.sh turn_by_turn.sh window_fix.sh cluster-map.template.esd "

unit=0
card=0
extras=""
for f in $FILES; do
    base=$(basename "$f")
    case "$UNIT_COPIES" in
        *" $base ")  unit=1; card=1; extras="$extras $f" ;;
        *) case "$f" in
               mod/cluster_map_aa_greenmenu/greenmenu/cluster-map.esd) card=1 ;;
               mod/*|thirdparty/*) card=1 ;;
           esac ;;
    esac
done

n=$(echo "$FILES" | grep -c .)
echo "## APPLY $TAG"
echo ""
echo "Changed since $PREV: $n files."
echo ""
if [ "$unit" = 0 ] && [ "$card" = 0 ]; then
    echo "Documentation-only release: NO card update needed; the installed map"
    echo "keeps running as it was; nothing to do beyond reading."
    exit 0
fi
echo "1. **Card update: yes** - put the zip's whole mod/ onto the card"
echo "   (merge over the card's own mod/ folder; card in SD slot 1)."
if [ "$unit" = 1 ]; then
    echo "2. **GEM re-run: yes** - M.I.B. -> Advanced settings ->"
    echo "   'Run /mod/custom.sh from m.i.b. SD'. This release changed a file"
    echo "   that already lives on the unit (the hook / the settings copy /"
    echo "   the screen source) - without this click the unit keeps running"
    echo "   the previous version of that file."
    echo "3. **Reboot: yes** (power button ~10 s). The map comes back with the"
    echo "   new release."
else
    echo "2. **GEM re-run: skip** - nothing the installer copies onto the unit"
    echo "   changed in this release; the installed files stay valid. Press"
    echo "   whatever ClusterMap entry you need, or just keep driving."
fi
echo "4. **Evidence loop**: ClusterMap -> 10/11. Save logs ->"
echo "   mod/cluster_aa/diag.txt (+ a cluster photo) whenever something looks"
echo "   off - that file is what most of this project's fixes were built on."
if [ -n "$extras" ]; then
    echo ""
    echo "The unit-copy files changed in this release:"
    for e in $extras; do echo "  - $e"; done
fi
exit 0
