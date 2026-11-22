"""FULL lifecycle round-trip: armed install -> uninstall -> virgin CLEAN,
plus the exit-code and leftover contracts the owner's car proved broken."""
import pathlib
import shutil

from conftest import APP_VIEWS, REPO, SYS_VIEWS

PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
SYS_CFG = "etc/eso/production/smartphone_integrator.json"


def _stage(car, armed=True):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    if armed:
        (dst / "HOOK_ARMED").write_text("")
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    cfg = '{\n "children": {\n  "gal": {\n   "envs":[] \n  },\n  "carplay": {\n   "envs":[] \n  }\n }\n}\n'
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG, cfg)
    return dst


def _press(car, verb, env=None):
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", verb], env=env,
                expect_rc=None)
    log = pathlib.Path(f"/tmp/cm_menu_{verb}.log")
    return p, (log.read_text() if log.exists() else "")


def test_armed_install_then_uninstall_then_virgin_is_clean(car):
    _stage(car, armed=True)
    p, text = _press(car, "install")
    assert p.returncode == 0, f"install failed:\n{text}\n{p.stdout}"
    assert "CLUSTERMAP_INSTALL_OK" in text, text
    # hook is live somewhere
    live = any("libgal_hook.so" in pathlib.Path(v, SYS_CFG).read_text()
               for v in SYS_VIEWS
               if pathlib.Path(v, SYS_CFG).exists())
    assert live, "armed install did not inject the hook"
    # a previous one-click run left its screen backup behind in every view
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/engdefs/cluster-map.esd.prev", "screen backup\n")

    p, text = _press(car, "uninstall")
    assert p.returncode == 0, f"uninstall failed:\n{text}\n{p.stdout}"
    assert "CLUSTERMAP_UNINSTALL_OK" in text, text
    for v in SYS_VIEWS:
        t = pathlib.Path(v, SYS_CFG)
        if t.exists():
            assert "libgal_hook.so" not in t.read_text(), f"hook survived in {v}"
    for v in APP_VIEWS:
        assert not pathlib.Path(v, "eso/hmi/engdefs/cluster-map.esd.prev").exists(), \
            f".prev survived uninstall in {v}"

    p, text = _press(car, "virgin")
    assert "VIRGIN UNIT: CLEAN" in text, f"virgin not clean:\n{text}"
    for v in APP_VIEWS:
        for rel in ("eso/hmi/engdefs/cluster-map.esd",
                    "eso/hmi/engdefs/cluster-map.esd.prev"):
            assert not pathlib.Path(v, rel).exists(), f"{v}/{rel} survived virgin"
    assert not pathlib.Path("/tmp/clustermap_install.log").exists(), \
        "stale install transcript survived virgin"


def test_install_on_clean_unit_without_preload_dir(car):
    """v0.7.37 install failure (owner photos: every remount rc=0, yet
    'every form failed'). On a clean unit the gal_dualscreen folder does
    not exist yet; the old probe fell through to the view ROOT, which this
    unit refuses, and declared every view unwritable. The install must
    succeed by probing the created target instead."""
    _stage(car, armed=True)
    # the car shape: writes at the view root refuse, subdirectories work;
    # no gal_dualscreen dir staged anywhere on purpose (clean unit).
    for v in APP_VIEWS:
        if pathlib.Path(v).exists():
            car.make_root_read_only(v)
    p, text = _press(car, "install")
    assert "CLUSTERMAP_INSTALL_OK" in text, \
        f"install failed on a clean unit:\n{text}"
    assert p.returncode == 0
    assert "without its own reason" not in text


def test_install_reports_failure_with_nonzero_rc(car):
    """enable_hook fails (no validator) -> install.sh must exit non-zero,
    not mask it with exit 0."""
    _stage(car, armed=True)
    # remove the validator everywhere: enable_hook cannot validate
    for v in APP_VIEWS:
        j = pathlib.Path(v, "eso/bin/jsonlint")
        if j.exists():
            j.unlink()
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", "install"], expect_rc=None)
    log = pathlib.Path("/tmp/cm_menu_install.log").read_text()
    assert "CLUSTERMAP_INSTALL_FAILED" in log, f"failure not named:\n{log}"
    assert "without its own reason" not in log, log
    assert "STOPPED" in p.stdout, f"failed install read as DONE:\n{p.stdout}"



def _clean_card_backup():
    """Virgin's card backup persists on the sim card across tests: remove
    it (and any read-only blocker) so later tests start unbacked-up."""
    import shutil
    for base in ("/fs/sda0/mod/cluster_aa/virgin-backup",
                 "/fs/sda0/mod/cluster_map_aa_greenmenu/virgin-backup"):
        bp = pathlib.Path(base)
        if bp.is_dir() and not bp.is_symlink():
            shutil.rmtree(bp, ignore_errors=True)
        elif bp.exists():
            bp.unlink(missing_ok=True)


def _valid_lsd(with_navignore=True):
    """A minimal lsd.sh that passes lsd_jar.sh check_new (>100 lines,
    main class path line, $J9 launch line)."""
    lines = ["#!/bin/sh", "BASE_DIR=/mnt/app"]
    lines += [f"# pad {i}" for i in range(120)]
    if with_navignore:
        lines.append('BOOTCLASSPATH="$BOOTCLASSPATH -Xbootclasspath/p:$BASE_DIR/lsd/jars/NavActiveIgnore.jar"')
    lines.append("FOO=Xbootclasspath/a:/ifs/lsd.jxe")
    lines.append("$J9 -jxe dummy")
    return "\n".join(lines) + "\n"


def test_virgin_cleans_marker_only_state_without_backups(car):
    """No hook in the config, no recovery copies anywhere, but our lsd
    marker + jar line linger (stage-only era, hand-deleted preload dir).
    Old code: disable_hook demanded backups and died
    ('Missing both recovery copies'), so uninstall/virgin could never get
    past it even though there was nothing to restore."""
    _stage(car, armed=False)
    fq = pathlib.Path(APP_VIEWS[1])
    car.stage(fq, "eso/hmi/lsd/lsd.sh", _valid_lsd())
    car.stage(fq, "eso/hmi/lsd/jars/NavActiveIgnore.jar", b"jar")
    car.stage(fq, "eso/hmi/lsd/.aacluster_navignore_added", b"marker")
    # no backups staged anywhere on purpose
    try:
        p, text = _press(car, "virgin")
        assert "Missing both recovery copies" not in text, \
            f"restore demanded with nothing to restore:\n{text}"
        assert "nothing to restore" in text, f"disable did not say so:\n{text}"
        assert "VIRGIN UNIT: CLEAN" in text, f"virgin not clean:\n{text}"
        lsd = pathlib.Path(fq, "eso/hmi/lsd/lsd.sh").read_text()
        assert "NavActiveIgnore" not in lsd, "jar line survived"
        for v in APP_VIEWS:
            assert not pathlib.Path(
                v, "eso/hmi/lsd/.aacluster_navignore_added").exists(), \
                f"marker survived in {v}"
    finally:
        _clean_card_backup()


def test_hook_in_config_without_backups_still_refuses(car):
    """Fail-closed is kept where it matters: the config references the
    hook but no backup exists -> disable must refuse, virgin must stop
    before scrubbing anything that would strand gal."""
    _stage(car, armed=False)
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG,
                  '{\n "children": { "gal": { "envs":['
                  '"LD_PRELOAD=/eso/lib/gal_dualscreen/libgal_hook.so"'
                  '] } }\n}\n')
    p, text = _press(car, "virgin")
    assert "FAIL: the restore step failed; nothing was scrubbed" in text, \
        f"virgin must stop before scrubbing past a failed restore:\n{text}"
    assert "VIRGIN UNIT: CLEAN" not in text, \
        f"a failed restore must never read as clean:\n{text}"
    assert "STOPPED" in p.stdout, f"menu verdict should be STOPPED:\n{p.stdout}"


def test_diag_reports_lsd_state(car):
    _stage(car, armed=False)
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/lsd.sh", _valid_lsd())
    log = pathlib.Path("/tmp/diag_lsd_probe.log")
    log.write_text("probe\n")
    car.run(["sh", f"{PKG}/greenmenu/diag_collect.sh",
             "append-run", str(log), "-v"], expect_rc=0)
    diag = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "6d Java start-up script" in diag
    assert "NavActiveIgnore.jar: LOADED" in diag


def test_lsd_jar_works_through_the_fqdn_view_only(car):
    """lsd.sh exists ONLY under the FQDN view: add/remove must still work."""
    _stage(car, armed=False)
    fq = pathlib.Path(APP_VIEWS[1])
    lsd = ("#!/bin/sh\n" + "\n".join(f"# pad {i}" for i in range(120)) +
           "\n$J9 -Xbootclasspath/a:/ifs/lsd.jxe\n")
    car.stage(fq, "eso/hmi/lsd/lsd.sh", lsd)
    car.stage(fq, "eso/hmi/lsd/jars/NavActiveIgnore.jar", b"jar-v1")
    p = car.run(["sh", f"{PKG}/scripts/lsd_jar.sh", "add", "NavActiveIgnore.jar",
                 f"{PKG}/thirdparty/NavActiveIgnore.jar"], expect_rc=None)
    assert p.returncode == 0, f"lsd add failed:\n{p.stdout}\n{p.stderr}"
    assert "NavActiveIgnore" in pathlib.Path(fq, "eso/hmi/lsd/lsd.sh").read_text()
    q = car.run(["sh", f"{PKG}/scripts/lsd_jar.sh", "remove", "NavActiveIgnore.jar"],
                expect_rc=None)
    assert q.returncode == 0, f"lsd remove failed:\n{q.stdout}\n{q.stderr}"


def test_virgin_backs_up_irreplaceable_files_to_card_first(car):
    """Owner rule: if something is deleted, copy it first to the SD card.
    The stock player sidecar + tracer .orig must land verified on the card
    before the unit originals go; virgin reports the backup folder."""
    _stage(car, armed=False)
    fq = pathlib.Path(APP_VIEWS[1])
    car.stage(fq, "navigation/stream-player.aacluster-original", b"stock-player-bytes")
    car.stage(fq, "eso/hmi/lsd/traceConfig.properties", "use.appender=client\n")
    car.stage(fq, "eso/hmi/lsd/traceConfig.properties.orig", "use.appender=client\n")
    try:
        p, text = _press(car, "virgin")
        assert "Card backup folder:" in text, f"no card backup happened:\n{text}"
        assert "VIRGIN UNIT: CLEAN" in text, f"virgin not clean:\n{text}"
        backed = list(pathlib.Path("/fs/sda0/mod/cluster_aa/virgin-backup").glob("*"))
        names = [b.name for b in backed]
        assert any(n.startswith("stream-player.aacluster-original.") for n in names), names
        assert any(n.startswith("traceConfig.properties.orig.lsd.") for n in names), names
        for v in APP_VIEWS:
            assert not pathlib.Path(v, "navigation/stream-player.aacluster-original").exists()
    finally:
        _clean_card_backup()


def test_virgin_keeps_irreplaceable_files_when_card_refuses(car):
    """Read-only card: no verified copy possible, so the unit file is KEPT
    and named STILL PRESENT instead of being deleted."""
    _stage(car, armed=False)
    fq = pathlib.Path(APP_VIEWS[1])
    car.stage(fq, "navigation/stream-player.aacluster-original", b"stock-player-bytes")
    blocker = pathlib.Path("/fs/sda0/mod/cluster_aa/virgin-backup")
    blocker.write_bytes(b"")  # a file where the backup dir must go
    try:
        p, text = _press(car, "virgin")
        assert "no writable card view" in text, f"card refusal not reported:\n{text}"
        assert "kept on unit: no verified card backup" in text, f"keep not named:\n{text}"
        assert (fq / "navigation/stream-player.aacluster-original").exists(), \
            "irreplaceable file deleted without a card copy"
        assert "VIRGIN UNIT: INCOMPLETE" in text, f"kept file must read as incomplete:\n{text}"
    finally:
        blocker.unlink(missing_ok=True)
        _clean_card_backup()


def test_tracer_child_must_not_close_the_installs_window(car):
    """v0.7.38 owner photos: the tracer auto-enable child remounted the
    app partition read-only on exit while the installer still had writes
    pending ('cannot create gal_dualscreen.conf.new: Read-only file
    system'). Contract, tested directly: under the installer flag the
    child must not emit any read-only remount; standalone (menu switch)
    it must still close its own window."""
    _stage(car, armed=True)
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/lsd/traceConfig.properties", "use.appender=client\n")
    tracer = f"{PKG}/greenmenu/wheel_tracer.sh"

    under = "/tmp/mountcalls_under.log"
    pathlib.Path(under).unlink(missing_ok=True)
    p = car.run(["sh", tracer, "on"],
                env={"CB_MOUNT_LOG": under,
                     "CLUSTERMAP_PARENT_OWNS_MOUNT": "1"}, expect_rc=None)
    assert "Wheel tracer: ON" in p.stdout, \
        f"tracer child path not exercised:\n{p.stdout}\n{p.stderr}"
    under_ops = [l.split()[0] for l in pathlib.Path(under).read_text().splitlines()
                 if l.strip() and "mnt/app" in l]
    assert "uw" in under_ops, f"child never opened a window:\n{under_ops}"
    assert "ur" not in under_ops, \
        f"child closed a window it does not own:\n{under_ops}"

    alone = "/tmp/mountcalls_alone.log"
    pathlib.Path(alone).unlink(missing_ok=True)
    q = car.run(["sh", tracer, "off"],
                env={"CB_MOUNT_LOG": alone}, expect_rc=None)
    assert "Wheel tracer: OFF" in q.stdout, f"{q.stdout}\n{q.stderr}"
    alone_ops = [l.split()[0] for l in pathlib.Path(alone).read_text().splitlines()
                 if l.strip() and "mnt/app" in l]
    assert "ur" in alone_ops, \
        f"standalone switch must leave the partition read-only:\n{alone_ops}"

def test_settings_copy_failure_is_not_masked():
    src = (REPO / "mod/cluster_map_aa_greenmenu/enable_hook.sh").read_text()
    i = src.find('cp "$SRC_CONF" "$CONF_COPY"')
    assert i > 0, "settings copy line moved"
    tail = src[i:i + 400]
    assert "|| true" not in tail.split("fi")[0], \
        f"the settings copy still swallows failures:\n{tail}"
    assert "Could not install the settings copy" in tail
