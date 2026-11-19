"""Uninstall/virgin lifecycle on a stock-ish unit.

Two car-proven failures from the owner's v0.7.33 diag:

1. A virgin press printed ONLY
   "FAIL: virgin child virgin.sh stopped rc=1 without its own reason",
   because virgin.sh scrubs /tmp/cm_menu_*.log -- the very file menus.sh
   redirects the child's stdout into. The reasons were written to an
   unlinked inode and lost.

2. The unit still carried engdefs/cluster-map.esd and its .prev backup.
   The app-writability probe only looks in eso/lib/gal_dualscreen, which
   is already GONE on a stock-ish unit; the app was reported read-only
   although the engdefs subdirectory accepts writes.

Also pins that uninstall no longer reports DONE when the restore failed.
"""
import pathlib
import shutil

from conftest import APP_VIEWS, REPO, SYS_VIEWS

PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
SYS_CFG = "etc/eso/production/smartphone_integrator.json"


def _stage(car):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    # stock supervisor config: no hook, no preload folder -> virgin skips
    # the restore step and goes straight to the scrub
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG, '{\n "children": { "gal": { "envs": [] } }\n}\n')
    return dst


def _press(car, verb):
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", verb], expect_rc=None)
    log = pathlib.Path(f"/tmp/cm_menu_{verb}.log")
    text = log.read_text() if log.exists() else ""
    diag = pathlib.Path("/tmp/clustermap_diag/diag.txt")
    return p, text, (diag.read_text() if diag.exists() else "")


def test_virgin_press_keeps_the_childs_own_reason(car):
    """A child that scrubs its own run log must not make the verdict lie."""
    _stage(car)
    # another mod's jar: the scrubber deliberately leaves it alone and
    # reports STILL PRESENT -- a real rc=1 with a named reason.
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/lsd/jars/NavActiveIgnore.jar", b"jar")
    p, text, diag = _press(car, "virgin")
    assert "STILL PRESENT" in text, \
        f"virgin's own reason was lost:\n--stdout--\n{p.stdout}\n--log--\n{text}"
    assert "without its own reason" not in text, \
        f"synthetic FAIL lied:\n{text}"
    assert "STILL PRESENT" in diag, "diag lost the reason too"
    assert "STOPPED" in p.stdout, f"menu verdict should be STOPPED:\n{p.stdout}"


def test_virgin_scrubs_gem_screen_without_the_preload_folder(car):
    """The engdefs write target is writable even when the preload folder
    and the view root refuse probes -- the exact stock-ish car shape."""
    _stage(car)
    for v in APP_VIEWS:
        if pathlib.Path(v).exists():
            car.make_root_read_only(v)     # root probes refused
        car.stage(v, "eso/hmi/engdefs/cluster-map.esd", "screen ClusterMap\n")
        car.stage(v, "eso/hmi/engdefs/cluster-map.esd.prev", "screen backup\n")
        # a byte-equal tracer .orig is ours and must be scrubbed too
        car.stage(v, "eso/hmi/lsd/traceConfig.properties", "use.appender=client\n")
        car.stage(v, "eso/hmi/lsd/traceConfig.properties.orig", "use.appender=client\n")
        car.stage(v, "eso/hmi/lsd/dsitracer_activated", b"marker")

    p, text, diag = _press(car, "virgin")
    assert "VIRGIN UNIT: CLEAN" in text, \
        f"virgin could not use the writable engdefs view:\n{text}\n{p.stdout}"
    for v in APP_VIEWS:
        for rel in ("eso/hmi/engdefs/cluster-map.esd",
                    "eso/hmi/engdefs/cluster-map.esd.prev",
                    "eso/hmi/lsd/traceConfig.properties.orig",
                    "eso/hmi/lsd/dsitracer_activated"):
            assert not pathlib.Path(v, rel).exists(), f"{v}/{rel} survived"
    assert "STOPPED" not in p.stdout, f"clean virgin read as failure:\n{p.stdout}"


def test_virgin_leaves_a_foreign_tracer_backup_named_but_untouched(car):
    """A .orig that does NOT match the live config may belong to someone
    else: never delete it, but never call the unit CLEAN either."""
    _stage(car)
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/lsd/traceConfig.properties", "use.appender=client\n")
        car.stage(v, "eso/hmi/lsd/traceConfig.properties.orig", "use.appender=telnet\n")
    p, text, diag = _press(car, "virgin")
    assert "backup differs from the live config" in text, \
        f"foreign backup not named:\n{text}"
    assert "VIRGIN UNIT: INCOMPLETE" in text, \
        f"a named leftover must not read as clean:\n{text}"


def test_uninstall_cleanup_uses_the_writable_qnet_view(car):
    """The owner's unit refuses `mount -uw /mnt/app` but honours the FQDN
    view. The old single-spelling cleanup skipped the player sidecar and
    the HMI tracer restore while still declaring the uninstall OK."""
    _stage(car)
    stock = '{\n "children": { "gal": { "envs": [] } }\n}\n'
    live = ('{\n "children": { "gal": { "envs":['
            '"LD_PRELOAD=/eso/lib/gal_dualscreen/libgal_hook.so"'
            '] } }\n}\n')
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG, live)
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG + ".gal-dualscreen.original", stock)
    fq = pathlib.Path(APP_VIEWS[1])
    tracer = "use.appender=client,telnet,bluepirat\n"
    car.stage(fq, "eso/hmi/lsd/traceConfig.properties", tracer)
    car.stage(fq, "eso/hmi/lsd/traceConfig.properties.orig", "use.appender=client\n")
    car.stage(fq, "navigation/stream-player.aacluster-original", b"stock-player")

    p = car.run(["sh", f"{PKG}/disable_hook.sh"],
                env={"CB_MOUNT_FAIL": "|/mnt/app|"}, expect_rc=None)
    assert p.returncode == 0, f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"
    assert not (fq / "navigation/stream-player.aacluster-original").exists(), \
        f"sidecar survived on the only writable view:\n{p.stdout}"
    assert (fq / "eso/hmi/lsd/traceConfig.properties").read_text() == \
        "use.appender=client\n", "the HMI tracer was not restored"
    assert "read-write via" in p.stdout, \
        f"cleanup never named the view it used:\n{p.stdout}"


def test_uninstall_does_not_report_done_when_the_restore_failed(car):
    """The old `exit 0` made a failed restore print FAILED and still tell
    the GEM verdict DONE."""
    _stage(car)
    # an installed unit (hook referenced) with NO recovery copies anywhere
    # -> disable_hook must fail and uninstall must not say OK
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG,
                  '{\n "children": { "gal": { "envs":['
                  '"LD_PRELOAD=/eso/lib/gal_dualscreen/libgal_hook.so"'
                  '] } }\n}\n')
    p, text, diag = _press(car, "uninstall")
    assert "CLUSTERMAP_UNINSTALL_FAILED" in text, \
        f"uninstall did not name its failure:\n{text}"
    assert "without its own reason" not in text, \
        f"the failure was swallowed:\n{text}"
