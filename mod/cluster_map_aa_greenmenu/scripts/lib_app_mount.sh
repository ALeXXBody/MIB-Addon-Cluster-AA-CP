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
    # CAR FACT: this unit REFUSES mkdir ("Function not implemented",
    # ENOSYS) while FILE writes next to it work - the hook's own log is a
    # file write, every boot. The old mkdir+rmdir probe therefore treated
    # a WORKING remount as a refusal (owner diag 2026-11-09: remount
    # rc=0 on four app views, then "every form failed"). Probe the thing
    # writes really depend on: a file write through this spelling.
    # (Subshell: dash aborts on a special builtin's failed redirect.)
    ( : > "$1/.clustermap_rw_probe" ) 2>/dev/null || return 1
    rm -f "$1/.clustermap_rw_probe" 2>/dev/null
    return 0
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
        _err=`mount -uw "$_f" 2>&1`; _rc=$?
        if [ "$_rc" -eq 0 ] && [ -z "$_err" ] && app_probe_view "$_f"; then
            APP_RW="$_f"; APP_LADDER_FORM="mount -uw $_f"
            APP_LADDER_OK="app: read-write via 'mount -uw $_f'"
            APP_WRITABLE=1; return 0
        fi
        APP_LADDER_ERRORS="${APP_LADDER_ERRORS}mount -uw $_f -> rc=$_rc: ${_err:-no message}$(echo)"
    done
    if command -v on >/dev/null 2>&1; then
        for _n in mmx rcc; do
            _err=`on -f "$_n" mount -uw /mnt/app 2>&1`; _rc=$?
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
            APP_LADDER_ERRORS="${APP_LADDER_ERRORS}on -f $_n mount -uw /mnt/app -> rc=$_rc: ${_err:-no message}$(echo)"
        done
    fi
    return 1
}

app_mount_finish()
{
    if [ "$APP_WRITABLE" -eq 1 ]; then
        if mount -ur "$APP_RW" 2>/dev/null; then
            APP_WRITABLE=0
        else
            echo "WARNING: could not remount $APP_RW read-only." >&2
            echo "         It is still writable. Run:  mount -ur $APP_RW" >&2
            echo "         before switching the car off." >&2
        fi
    fi
}

# Callers should call this from their own finish()/trap handler, after
# handling whatever else that script's finish() is responsible for (e.g.
# SYSTEM_MOUNT cleanup, which is script-specific and not handled here).
app_mount_finish()
{
    if [ "$APP_WRITABLE" -eq 1 ]; then
        # Do not swallow a failed remount. This runs from a trap, so the
        # exit status goes nowhere -- but leaving the internal partition
        # writable is not a cosmetic problem on a device that loses power
        # by having its ignition switched off, and the operator is the
        # only one who can act on it. The flag is cleared only on success,
        # so a caller that runs this twice will try again.
        if mount -ur "$APP_MOUNT" 2>/dev/null; then
            APP_WRITABLE=0
        else
            echo "WARNING: could not remount $APP_MOUNT read-only." >&2
            echo "         It is still writable. Run:  mount -ur $APP_MOUNT" >&2
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
            mv "$PF.clustermap-new" "$PF" && echo "Firewall: CarPlay map port closed in $PF"
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
            mv "$PF.clustermap-new" "$PF" && echo "Firewall: CarPlay map port 6031 opened on carplay0 in $PF" ||
            { rm -f "$PF.clustermap-new"; echo "Firewall: could not edit $PF; the CarPlay map may get no video"; }
    done
}
