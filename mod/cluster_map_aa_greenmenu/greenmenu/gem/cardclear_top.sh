#!/bin/sh
# GEM screen entry wrapper. M.I.B. convention: a screen's script
# value is a BARE path (the GEM resolves the whole quoted string
# as the script name), so arguments travel inside these files.
HERE=`dirname "$0"`
exec sh "$HERE/../menus.sh" cardclear top
