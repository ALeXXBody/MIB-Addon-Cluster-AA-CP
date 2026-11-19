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


def _press(car, verb):
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", verb], expect_rc=None)
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
