# Shared by enable_hook.sh and disable_hook.sh: where the preload target
# lives on the internal /mnt/app partition, and the mount-guard cleanup
# for it.
#
# Under /eso/lib specifically, not /navigation: this firmware's own
# smartphone_integrator.json already has a "mirrorlink" child using
# LD_PRELOAD=/eso/lib/libsystemtime_hack.so, direct proof (not just
# analogy) that this exact framework relies on LD_PRELOAD from this exact
# path working reliably for a supervised child. /navigation was considered
# and rejected: it is also on /mnt/app and would likely work the same way,
# but it holds map/POI data content that a future navigation update could
# resync or clean, silently deleting an unrelated subdirectory placed
# inside it. /eso/lib is vendor framework code, not managed content, and
# is not going to be swept by anything that isn't a full firmware update.
# M.I.B. GEM scripts can run on a node whose /mnt/app is NOT the node that
# owns the app partition (or where plain `mount -uw /mnt/app` is not
# honoured). The ladder of view-forms is what M.I.B.'s own toolbox uses:
#   mount -uw /net/mmx/mnt/app         (network view - apps/launcher uses it)
#   on -f mmx mount -uw /mnt/app       (remount on the owning node)
#   on -f rcc mount -uw /mnt/app
#   mount -uw /mnt/app                 (last, plain)
# app_mount_rw() probes each form and selects an ALIAS whose mount actually
# went read-write. Every later write must go through the SAME alias, and
# remount-ro happens on it too. $APP_MOUNT keeps /mnt/app for compatibility;
# $APP_RW is the alias that works (defaults to $APP_MOUNT).
#
# View spellings, best-first. MHI2 shows the QNET FQDN form
# (/net/mmx.mibhigh.net/dev/... in `mount`), and a console node may resolve
# ONLY that form for file paths; the /net/mmx/... shorthand and the local
# /mnt/app alias are not guaranteed to exist where the script runs. The
# ladder tries every spelling, and -- critical -- probes writability
# THROUGH THE SAME SPELLING it plans to write through.
APP_MOUNT=/mnt/app
APP_VIEWS="/mnt/app /net/mmx.mibhigh.net/mnt/app /net/mmx/mnt/app /net/rcc/mnt/app"
SYSTEM_MOUNT=/mnt/system
SYS_VIEWS="/mnt/system /net/mmx.mibhigh.net/mnt/system /net/mmx/mnt/system /net/rcc/mnt/system"
PRELOAD_WRITE_DIR="$APP_MOUNT/eso/lib/gal_dualscreen"
PRELOAD_SO_ALIAS=/eso/lib/gal_dualscreen/libgal_hook.so
PRELOAD_SO_REAL="$PRELOAD_WRITE_DIR/libgal_hook.so"
APP_WRITABLE=0
APP_RW="$APP_MOUNT"
APP_LADDER_FORM=

# The first app view that EXISTS on this node (for read-only needs like
# finding jsonlint). Unlike app_mount_rw() this does not remount anything.
app_pick_view()
{
    for _v in $APP_VIEWS; do
        [ -d "$_v" ] && { echo "$_v"; return 0; }
    done
    return 1
}

# The first system view that EXISTS on this node (read-only needs like
# reading the supervisor config or jsonlint staging). No remount happens.
system_pick_view()
{
    for _v in $SYS_VIEWS; do
        [ -d "$_v" ] && { echo "$_v"; return 0; }
    done
    return 1
}

# Writability probe, run THROUGH one specific view spelling.
app_probe_view()
{
    # CAR FACTS baked into one probe (diag 2026-11-09: remount rc=0 on
    # four app views, then "every form failed"):
    #   1. this unit REFUSES mkdir (ENOSYS) - only a file write works;
    #   2. writes at the app view's ROOT refuse while SUBDIRECTORY writes
    #      work (the same boot's engdefs write succeeded through the very
    #      alias the root probe refused);
    #   3. the write target of every app write in this payload is
    #      $1/eso/lib/gal_dualscreen (settings copy, hook, backups).
    # So probe AT THE WORK TARGET first, fall back to the view root.
    # (Subshell: dash aborts on a special builtin's failed redirect.)
    # The v0.7.3 refinement: the probe also RECORDS why every one of its
    # attempts refused - one per form in $APP_LADDER_ERRORS. A car diag
    # therefore names the reason (ENO.../Permission) rather than the
    # same "every form failed" verdict.
    if [ -d "$1/eso/lib/gal_dualscreen" ]; then
        _err=`{ ( : > "$1/eso/lib/gal_dualscreen/.clustermap_rw_probe" ); } 2>&1` || true
        if [ -z "$_err" ]; then
            rm -f "$1/eso/lib/gal_dualscreen/.clustermap_rw_probe" 2>/dev/null
            return 0
        fi
        APP_LADDER_ERRORS="${APP_LADDER_ERRORS}write probe at $1/eso/lib/gal_dualscreen: ${_err:-(no message)}
"
    else
        APP_LADDER_ERRORS="${APP_LADDER_ERRORS}write probe at $1/eso/lib/gal_dualscreen: (folder absent in this view)
"
    fi
    _err=`{ ( : > "$1/.clustermap_rw_probe" ); } 2>&1` || true
    if [ -z "$_err" ]; then
        rm -f "$1/.clustermap_rw_probe" 2>/dev/null
        return 0
    fi
    APP_LADDER_ERRORS="${APP_LADDER_ERRORS}write probe at $1 root: ${_err:-(no message)}
"
    return 1
}

# Every attempt's REAL error is recorded (the owner's rule: measured, not
# guessed); $APP_LADDER_ERRORS carries one line per attempt so the diag
# answers "why could nothing remount" on its own. $APP_LADDER_OK records
# the form that worked.
APP_LADDER_ERRORS=""
APP_LADDER_OK=""
app_mount_rw()
{
    for _f in $APP_VIEWS; do
        [ -d "$_f" ] || continue
        _rc=0
        _err=`mount -uw "$_f" 2>&1` || _rc=$?
        if [ "$_rc" -eq 0 ] && [ -z "$_err" ]; then
            if app_probe_view "$_f"; then
                APP_RW="$_f"; APP_LADDER_FORM="mount -uw $_f"
                APP_LADDER_OK="app: read-write via 'mount -uw $_f'"
                APP_WRITABLE=1; return 0
            fi
        fi
        APP_LADDER_ERRORS="${APP_LADDER_ERRORS}mount -uw $_f -> rc=$_rc: ${_err:-no message}
"
    done
    if command -v on >/dev/null 2>&1; then
        for _n in mmx rcc; do
            _rc=0
            _err=`on -f "$_n" mount -uw /mnt/app 2>&1` || _rc=$?
            if [ "$_rc" -eq 0 ] && [ -z "$_err" ]; then
                for _pf in /net/$_n.mibhigh.net/mnt/app /net/$_n/mnt/app /mnt/app; do
                    # The remount succeeded on the owning node; the probe
                    # must go through a view THIS node can actually address
                    # (the local /mnt/app spelling may be absent here even
                    # when the owning node's mount just went rw).
                    if [ -d "$_pf" ] && app_probe_view "$_pf"; then
                        APP_RW="$_pf"; APP_LADDER_FORM="on -f $_n mount -uw /mnt/app (write view: $_pf)"
                        APP_LADDER_OK="app: read-write via 'on -f $_n mount -uw /mnt/app' (view $_pf)"
                        APP_WRITABLE=1; return 0
                    fi
                done
            fi
            APP_LADDER_ERRORS="${APP_LADDER_ERRORS}on -f $_n mount -uw /mnt/app -> rc=$_rc: ${_err:-no message}
"
        done
    fi
    return 1
}

# Callers should call this from their own finish()/trap handler, after
# handling whatever else that script's finish() is responsible for (e.g.
# SYSTEM_MOUNT cleanup, which is script-specific and not handled here).
# It remounts the view the ladder actually made writable ($APP_RW), not the
# /mnt/app spelling -- on a console node where /mnt/app is not the writable
# view, remounting /mnt/app would leave the real one writable.
app_mount_finish()
{
    if [ "$APP_WRITABLE" -eq 1 ]; then
        # Do not swallow a failed remount. This runs from a trap, so the
        # exit status goes nowhere -- but leaving the internal partition
        # writable is not a cosmetic problem on a device that loses power
        # by having its ignition switched off, and the operator is the
        # only one who can act on it. The flag is cleared only on success,
        # so a caller that runs this twice will try again.
        if mount -ur "$APP_RW" 2>/dev/null; then
            APP_WRITABLE=0
        else
            echo "WARNING: could not remount $APP_RW read-only." >&2
            echo "         It is still writable. Run:  mount -ur $APP_RW" >&2
            echo "         before switching the car off." >&2
        fi
    fi
}

# The CarPlay map's firewall rule. The iPhone sends the cluster video to
# TCP 6031 (harman-f's stream 111 receiver), but the unit's packet filter
# drops every port on carplay0 (the iPhone's USB link) that is not in its
# CarPlay list, and 6031 is not (car-verified on a Golf R: the phone set up
# the stream and never connected). One pass rule for that port on carplay0
# only is added after the stock CarPlay line, in each /mnt/system/etc/pf*.conf
# (the unit picks one by connection type), as the MIB2 Toolbox does for SSH.
# Marked, so removal takes out only our line; read at the next boot.
# Both need $SYSTEM_MOUNT writable.
CARPLAY_PF_MARK="# clustermap carplay map"
CARPLAY_PF_RULE="pass in quick on carplay0 proto tcp from any to any port 6031 allow-opts $CARPLAY_PF_MARK"

carplay_pf_close()
{
    for PF in /mnt/system/etc/pf*.conf; do
        [ -f "$PF" ] && grep -q "$CARPLAY_PF_MARK" "$PF" || continue
        cp -p "$PF" "$PF.clustermap-new" &&
            grep -v "$CARPLAY_PF_MARK" "$PF" > "$PF.clustermap-new" &&
            fat_mv "$PF.clustermap-new" "$PF" && echo "Firewall: CarPlay map port closed in $PF"
    done
}

carplay_pf_open()
{
    carplay_pf_close >/dev/null
    for PF in /mnt/system/etc/pf*.conf; do
        [ -f "$PF" ] && grep -q '^pass in quick on carplay0 proto tcp ' "$PF" || continue
        [ -f "$PF.clustermap.original" ] || cp -p "$PF" "$PF.clustermap.original"
        # Started as a copy so the file keeps its owner and mode.
        cp -p "$PF" "$PF.clustermap-new" && awk -v rule="$CARPLAY_PF_RULE" '
            { print }
            !done && /^pass in quick on carplay0 proto tcp / { print rule; done=1 }
        ' "$PF" > "$PF.clustermap-new" && grep -q "$CARPLAY_PF_MARK" "$PF.clustermap-new" &&
            fat_mv "$PF.clustermap-new" "$PF" && echo "Firewall: CarPlay map port 6031 opened on carplay0 in $PF" ||
            { rm -f "$PF.clustermap-new"; echo "Firewall: could not edit $PF; the CarPlay map may get no video"; }
    done
}

# live_write FILE VALUE - write one of the /tmp runtime overrides and
# verify the readback. The switches write these FIRST, before any
# remount: the hook reads them live, and a refused app-partition remount
# must never take the live arm down with it (the v0.7.5 car round: every
# switch wrote its runtime file AFTER the ladder, so on a car whose
# remount refuses, nothing was ever armed).
live_write()
{
    _lw_f="$1"
    _lw_v="$2"
    echo "$_lw_v" > "$_lw_f" 2>/dev/null || {
        echo "Cannot write $_lw_f - the runtime override did not land. Nothing changed." >&2
        return 1
    }
    if [ "`cat "$_lw_f" 2>/dev/null`" != "$_lw_v" ]; then
        echo "Runtime override $_lw_f did not read back. Nothing changed." >&2
        return 1
    fi
    return 0
}

# Where the hook's runtime override files live. /tmp on the unit, always --
# the hook has that literal path compiled in. The offline car simulation
# overrides it so its tests never touch a real /tmp; anything that ships
# must see /tmp here.
GAL_RUNTIME_DIR="${GAL_RUNTIME_DIR:-/tmp}"

# ---------------------------------------------------------------------------
# The SYSTEM partition ladder -- the same shape as app_mount_rw().
#
# v0.7.4 died on this car at
#   "Cannot remount the system partition read-write. Forms tried: ..."
# although the remount itself very likely SUCCEEDED. Its probe was a file
# write at the mount ROOT, and this unit refuses writes at partition roots
# (ENOSYS) while a SUBDIRECTORY write works -- measured on the app
# partition in the same boot (root probe refused, the engdefs write through
# the same alias succeeded). So the probe has to live at the actual write
# TARGET: etc/eso/production, where smartphone_integrator.json and its
# backup are written.
#
# It also only tried the four path spellings with a plain `mount -uw`.
# M.I.B.'s own toolbox remounts ON THE OWNING NODE, and a console node may
# not honour a local remount at all. Both are tried, in the same order the
# app ladder uses, and every attempt's real error is kept in
# $SYSTEM_LADDER_ERRORS so a diag names the reason for each form.
SYSTEM_LADDER_ERRORS=""
SYSTEM_LADDER_OK=""
SYSTEM_RW=""

system_probe_view()
{
    _sy_dir="$1/etc/eso/production"
    if [ -d "$_sy_dir" ]; then
        _sy_err=`{ ( : > "$_sy_dir/.clustermap_sys_probe" ); } 2>&1` || true
        if [ -z "$_sy_err" ]; then
            rm -f "$_sy_dir/.clustermap_sys_probe" 2>/dev/null
            return 0
        fi
        SYSTEM_LADDER_ERRORS="${SYSTEM_LADDER_ERRORS}write probe at $_sy_dir: ${_sy_err:-(no message)}
"
    else
        SYSTEM_LADDER_ERRORS="${SYSTEM_LADDER_ERRORS}write probe at $_sy_dir: (folder absent in this view)
"
    fi
    _sy_err=`{ ( : > "$1/.clustermap_sys_probe" ); } 2>&1` || true
    if [ -z "$_sy_err" ]; then
        rm -f "$1/.clustermap_sys_probe" 2>/dev/null
        return 0
    fi
    SYSTEM_LADDER_ERRORS="${SYSTEM_LADDER_ERRORS}write probe at $1 root: ${_sy_err:-(no message)}
"
    return 1
}

system_mount_rw()
{
    SYSTEM_LADDER_ERRORS=""
    SYSTEM_LADDER_OK=""
    SYSTEM_RW=""
    for _f in $SYS_VIEWS; do
        [ -d "$_f" ] || continue
        _rc=0
        _err=`mount -uw "$_f" 2>&1` || _rc=$?
        if [ "$_rc" -eq 0 ] && [ -z "$_err" ] && system_probe_view "$_f"; then
            SYSTEM_RW="$_f"
            SYSTEM_LADDER_OK="system: read-write via 'mount -uw $_f'"
            return 0
        fi
        SYSTEM_LADDER_ERRORS="${SYSTEM_LADDER_ERRORS}mount -uw $_f -> rc=$_rc: ${_err:-no message}
"
    done
    if command -v on >/dev/null 2>&1; then
        for _n in mmx rcc; do
            _rc=0
            _err=`on -f "$_n" mount -uw /mnt/system 2>&1` || _rc=$?
            if [ "$_rc" -eq 0 ] && [ -z "$_err" ]; then
                for _pf in /net/$_n.mibhigh.net/mnt/system /net/$_n/mnt/system /mnt/system; do
                    if [ -d "$_pf" ] && system_probe_view "$_pf"; then
                        SYSTEM_RW="$_pf"
                        SYSTEM_LADDER_OK="system: read-write via 'on -f $_n mount -uw /mnt/system' (view $_pf)"
                        return 0
                    fi
                done
            fi
            SYSTEM_LADDER_ERRORS="${SYSTEM_LADDER_ERRORS}on -f $_n mount -uw /mnt/system -> rc=$_rc: ${_err:-no message}
"
        done
    fi
    # Nothing won: leave no form writable behind us.
    for _f in $SYS_VIEWS; do
        mount -ur "$_f" 2>/dev/null || true
    done
    return 1
}

# ---------------------------------------------------------------------------
# Persisting settings keys: the unit copy first, the card root as fallback.
#
# THE BLIND SPOT THIS CLOSES. The hook loads the FIRST file that exists
# among
#   /fs/sdb0/gal_dualscreen.conf, /fs/sda0/gal_dualscreen.conf,
#   /eso/lib/gal_dualscreen/gal_dualscreen.conf, /tmp/gal_dualscreen.conf
# so a card-root file SHADOWS the unit copy. v0.7.4 fell back to the card
# when the unit copy refused its remount, and from then on every switch
# that only wrote the unit copy changed a file nothing reads -- "the
# switch says saved, nothing changes". Therefore: if a card-root file
# exists, it IS the settings file and every later switch updates it.
# Without one, the unit copy is written through the app ladder, and the
# card file is only created when that refuses.
#
# The card is touched ONLY here, on a deliberate settings change. Boot,
# install, uninstall and the diagnostics never write it (owner rule: the
# card is read-only media during normal operation).

# fat_mv SRC DST - FAT-safe replace. The card is FAT/exFAT: rename
# onto an existing name fails (EEXIST) where tmpfs/ext4 replaces
# atomically. Remove first, then move; fall back to a copy when the
# move itself is refused. Returns 0 on success.
fat_mv()
{
    rm -f "$2" 2>/dev/null
    if mv "$1" "$2" 2>/dev/null; then return 0; fi
    if cat "$1" > "$2" 2>/dev/null; then rm -f "$1" 2>/dev/null; return 0; fi
    rm -f "$1" 2>/dev/null
    return 1
}

# conf_file_apply MODE FILE KEY[=VALUE] ...
#   MODE = set   (KEY=VALUE): replace/append the key
#   MODE = clear (KEY)      : remove the key
#   KEY= (empty) also clears, so callers can pass a pair list uniformly.
# Removes the key first (every occurrence), then appends the new line at
# the end, through FILE.new + rename -- no sed -i on FAT, and a torn write
# can never leave a half-rewritten settings file. Returns 1 if unwritable.
conf_file_apply()
{
    _cfa_mode=$1; _cfa_f=$2; shift 2
    _cfa_keys=""; _cfa_vals=""
    for _a in "$@"; do
        case "$_cfa_mode" in
            clear) _cfa_k=$_a; _cfa_v="" ;;
            *)     case "$_a" in
                       *=*) _cfa_k=${_a%%=*}; _cfa_v=${_a#*=} ;;
                       *)   _cfa_k=$_a; _cfa_v="" ;;
                   esac ;;
        esac
        [ -n "$_cfa_k" ] || continue
        _cfa_keys="$_cfa_keys $_cfa_k"
        if [ -n "$_cfa_v" ]; then _cfa_vals="$_cfa_vals
$_cfa_k=$_cfa_v"; fi
    done
    [ -f "$_cfa_f" ] || return 1
    awk -v keys="$_cfa_keys" -v vals="$_cfa_vals" '
        BEGIN {
            n = split(keys, K, " ")
            for (i = 1; i <= n; i++) if (K[i] != "") rm[K[i]] = 1
            m = split(vals, V, "\n")
        }
        {
            line = $0
            eq = index(line, "=")
            if (eq > 0) {
                k = substr(line, 1, eq - 1)
                if (k in rm) next
            }
            print
        }
        END {
            for (i = 1; i <= m; i++) if (V[i] != "") print V[i]
        }
    ' "$_cfa_f" > "$_cfa_f.new" 2>/dev/null || { rm -f "$_cfa_f.new"; return 1; }
    fat_mv "$_cfa_f.new" "$_cfa_f" || { rm -f "$_cfa_f.new"; return 1; }
    return 0
}

# conf_file_verify MODE FILE KEY[=VALUE] ... - readback check, same syntax.
conf_file_verify()
{
    _cfv_mode=$1; _cfv_f=$2; shift 2
    [ -r "$_cfv_f" ] || return 1
    for _a in "$@"; do
        case "$_cfv_mode" in
            clear) _cfv_k=$_a; _cfv_want="" ;;
            *)     case "$_a" in
                       *=*) _cfv_k=${_a%%=*}; _cfv_want=${_a#*=} ;;
                       *)   _cfv_k=$_a; _cfv_want="" ;;
                   esac ;;
        esac
        [ -n "$_cfv_k" ] || continue
        _cfv_now=`sed -n "s/^$_cfv_k=//p" "$_cfv_f" 2>/dev/null | tail -1`
        [ "$_cfv_now" = "$_cfv_want" ] || return 1
    done
    return 0
}

# conf_card_write MODE KEY[=VALUE] ... - write the card-root settings file.
# One rw window: probe, build the union, verify, remount ro.
conf_card_write()
{
    _ccw_mode=$1; shift
    _ccw_root=""
    for _v in /fs/sda0 /fs/sdb0 /net/mmx/fs/sda0 /net/mmx/fs/sdb0 \
              /net/mmx.mibhigh.net/fs/sda0 /net/mmx.mibhigh.net/fs/sdb0; do
        [ -d "$_v" ] || continue
        if [ -d "$_v/mod/cluster_aa" ] || [ -d "$_v/mod/cluster_map_aa_greenmenu" ] || \
           [ -f "$_v/gal_dualscreen.conf" ]; then
            _ccw_root="$_v"; break
        fi
    done
    if [ -z "$_ccw_root" ]; then
        echo "No card found (looked for the payload or a settings file on every view)." >&2
        return 1
    fi
    _ccw_conf="$_ccw_root/gal_dualscreen.conf"
    _ccw_new="$_ccw_root/.galconf.new.$$"

    _ccw_remounted=0
    if ! ( : > "$_ccw_root/.galconf_probe" ) 2>/dev/null; then
        if ! mount -uw "$_ccw_root" 2>/dev/null; then
            echo "Cannot remount the card read-write ($_ccw_root). Nothing changed." >&2
            return 1
        fi
        _ccw_remounted=1
        if ! ( : > "$_ccw_root/.galconf_probe" ) 2>/dev/null; then
            echo "The card refused a file write even after the remount. Nothing changed." >&2
            rm -f "$_ccw_root/.galconf_probe" 2>/dev/null
            mount -ur "$_ccw_root" 2>/dev/null || true
            return 1
        fi
    fi
    rm -f "$_ccw_root/.galconf_probe" 2>/dev/null

    # BASE: the card file itself when it exists (it is what the hook
    # reads), else the unit copy, else the shipped conf beside the payload.
    # The union matters: the card file REPLACES the unit copy for the hook.
    _ccw_base=""
    if [ -f "$_ccw_conf" ]; then
        _ccw_base="$_ccw_conf"
    else
        for _v in $APP_VIEWS; do
            if [ -r "$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf" ]; then
                _ccw_base="$_v/eso/lib/gal_dualscreen/gal_dualscreen.conf"; break
            fi
        done
    fi
    # Probe creatability FIRST, then seed from the base (the old order
    # truncated the seeded copy with the probe and dropped every line except
    # the one being set).
    ( : > "$_ccw_new" ) 2>/dev/null || {
        echo "Cannot create $_ccw_new. Nothing changed." >&2
        [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
        return 1
    }
    if [ -n "$_ccw_base" ]; then
        cat "$_ccw_base" > "$_ccw_new" 2>/dev/null || {
            echo "Could not seed $_ccw_new. Nothing changed." >&2
            rm -f "$_ccw_new" 2>/dev/null
            [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
            return 1
        }
    fi
    if ! conf_file_apply "$_ccw_mode" "$_ccw_new" "$@"; then
        echo "Could not prepare the new settings file. Nothing changed." >&2
        rm -f "$_ccw_new" 2>/dev/null
        [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
        return 1
    fi
    if ! conf_file_verify "$_ccw_mode" "$_ccw_new" "$@"; then
        echo "The prepared settings file failed its readback. Nothing changed." >&2
        rm -f "$_ccw_new" 2>/dev/null
        [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
        return 1
    fi
    if ! fat_mv "$_ccw_new" "$_ccw_conf"; then
        echo "Could not write $_ccw_conf. Nothing changed." >&2
        rm -f "$_ccw_new" 2>/dev/null
        [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
        return 1
    fi
    sync 2>/dev/null || true
    if ! conf_file_verify "$_ccw_mode" "$_ccw_conf" "$@"; then
        echo "WARNING: $_ccw_conf did not read back as written." >&2
        [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
        return 1
    fi
    [ "$_ccw_remounted" = 1 ] && mount -ur "$_ccw_root" 2>/dev/null
    CONF_PERSIST_WHERE="card root ($_ccw_conf)"
    return 0
}

# conf_persist set|clear KEY[=VALUE] [...] - persist keys for the next gal
# start and leave the app partition read-only again. Sets CONF_PERSISTED:
#   0 refused (nothing persisted), 1 the unit copy, 2 the card root.
# The app copy is remounted ro on every exit path (the v0.7.5 switches
# used to leave it writable until the next ignition cycle).
CONF_PERSISTED=0
CONF_PERSIST_WHERE=""

# conf_card_file - the card-root settings file the hook would load first,
# or empty. One list, used by every caller that has to know WHICH file is
# live (a card-root file shadows the unit copy).
conf_card_file()
{
    for _v in /fs/sda0 /fs/sdb0 /net/mmx/fs/sda0 /net/mmx/fs/sdb0 \
              /net/mmx.mibhigh.net/fs/sda0 /net/mmx.mibhigh.net/fs/sdb0; do
        if [ -f "$_v/gal_dualscreen.conf" ]; then
            echo "$_v/gal_dualscreen.conf"
            return 0
        fi
    done
    return 1
}

conf_persist()
{
    CONF_PERSISTED=0
    CONF_PERSIST_WHERE=""
    _cp_mode=$1; shift
    [ "$_cp_mode" = set ] || [ "$_cp_mode" = clear ] || _cp_mode=set

    # A card-root file already shadows the unit copy: update THE file the
    # hook reads, never the shadowed one.
    _cp_card=`conf_card_file` || _cp_card=""
    if [ -n "$_cp_card" ]; then
        if conf_card_write "$_cp_mode" "$@"; then
            CONF_PERSISTED=2
            return 0
        fi
        return 1
    fi

    if app_mount_rw; then
        _cp_conf="$APP_RW/eso/lib/gal_dualscreen/gal_dualscreen.conf"
        if conf_file_apply "$_cp_mode" "$_cp_conf" "$@" && \
           conf_file_verify "$_cp_mode" "$_cp_conf" "$@"; then
            sync 2>/dev/null || true
            CONF_PERSISTED=1
            CONF_PERSIST_WHERE="unit copy ($_cp_conf)"
            [ -n "$APP_LADDER_OK" ] && echo "$APP_LADDER_OK"
            app_mount_finish
            return 0
        fi
        app_mount_finish
    fi

    if conf_card_write "$_cp_mode" "$@"; then
        CONF_PERSISTED=2
        return 0
    fi
    return 1
}
