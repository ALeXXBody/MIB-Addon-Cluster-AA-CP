#!/bin/sh
# GEM entry wrapper (bare path; the GEM resolves the whole
# quoted value as the script name - M.I.B. convention).
HERE=`dirname "$0"`
exec sh "$HERE/../menus.sh" etacard right
