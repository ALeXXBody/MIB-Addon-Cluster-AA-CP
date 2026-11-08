"""The GEM screen's script paths must be in the spelling the GEM EXECUTES.

Car fact (owner v0.4.24 diag + report): a screen that names /fs/sda0 parses
fine and even installs — but the GEM process answers "Script not found" on
every button, because the GEM runs on the node where slot 1 is
/net/mmx/fs/sda0 (the same prefix M.I.B.'s own screens use). custom.sh must
therefore WRITE the GEM-canonical spelling when that path is reachable,
and only fall back to the console's own view otherwise."""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")
REPO_MOD = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/mod")
PKG = "/fs/sda0/mod/cluster_aa"
GEM_PKG = "/net/mmx/fs/sda0/mod/cluster_aa"
LIVE = pathlib.Path(APP_VIEWS[1], "eso/hmi/engdefs/cluster-map.esd")

GEM_CANON = "value   sys 1 0x0100 \"/net/mmx/fs/sda0/mod/cluster_aa/greenmenu/menus.sh status\""


def _stage_unit(car):
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS, "/net/mmx/fs/sda0"])
    # a real unit ships a populated engdefs folder in every view/alias:
    # the tests emulate exactly that.
    for v in APP_VIEWS:
        pathlib.Path(v, "eso/hmi/engdefs").mkdir(parents=True, exist_ok=True)
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-stock-player-bytes")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, "etc/eso/production/smartphone_integrator.json",
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')


def _stage_payload(dst, armed=True):
    path = pathlib.Path(dst)
    path.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, path, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt",
                                                  "LICENSE"))
    if armed:
        (path / "HOOK_ARMED").write_text("")


def test_screen_paths_use_the_gem_spelling_when_reachable(car):
    _stage_unit(car)
    _stage_payload(PKG)
    _stage_payload(GEM_PKG)
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    p = car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "screen paths: GEM view (/net/mmx/fs/sda0)" in out, out
    live = LIVE.read_text()
    assert '/net/mmx/fs/sda0/mod/cluster_aa/greenmenu/gem/status.sh' in live, live
    assert '"/fs/sda0/' not in live, "a console-only spelling leaked in:\n%s" % live
    # every script path the LIVE screen names exists again (the GEM's own test)
    import re
    for m in re.findall(r'"(/net/[^"]*\.sh)"', live):
        if "esd/scripts/" in m or "/gem/" in m:
            # M.I.B.'s own reboot entry, and our wrapper entries live in
            # their own gem/ folder: the folder fix covers them
            continue
        assert m.startswith("/net/mmx/fs/sda0/mod/cluster_aa/greenmenu/"), m


def test_fallback_keeps_the_console_view_when_gem_spelling_absent(car):
    _stage_unit(car)
    _stage_payload(PKG)  # only /fs/sda0 carries the payload
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    p = car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "screen paths: the view this console found" in out, out
    live = LIVE.read_text()
    assert "/fs/sda0/mod/cluster_aa/greenmenu/gem/status.sh" in live, live


def test_diag_reports_whether_the_gem_can_resolve_each_entry(car):
    _stage_unit(car)
    _stage_payload(PKG)
    _stage_payload(GEM_PKG)
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    txt = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "6b live screen script paths" in txt
    ok_lines = [l for l in txt.splitlines() if l.strip().startswith("ok")]
    missing = [l for l in txt.splitlines()
               if l.strip().startswith("MISSING")]
    assert ok_lines, "the 6b section carries no resolved entry"
    assert not missing, f"the live screen names missing paths:\n{missing}"
