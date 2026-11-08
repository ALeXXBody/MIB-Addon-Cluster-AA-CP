"""mod/custom.sh end-to-end, offline: the screen write is SAFE (never
truncates the unit's live engdefs file with unverified content), the
previous screen is kept as .prev, and the installer still runs through the
FQDN view. This is the GEM-boot hang regression test."""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo")
PKG = "/fs/sda0/mod/cluster_map_aa_greenmenu"
CUSTOM = "/fs/sda0/mod/custom.sh"
ENGDEFS = pathlib.Path(APP_VIEWS[1], "eso/hmi/engdefs")
PREV_GOOD = "PREVIOUS-GOOD-SCREEN-CONTENTS\n"
TPL = pathlib.Path(PKG, "greenmenu/cluster-map.template.esd")
LIVE = ENGDEFS / "cluster-map.esd"
PREV = ENGDEFS / "cluster-map.esd.prev"


def _stage(car):
    # card content: the mod payload AND the repo's mod/custom.sh at the card root
    dst = pathlib.Path("/fs/sda0/mod/cluster_map_aa_greenmenu")
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "HOOK_ARMED").write_text("")  # armed: registration + hook in one step
    src = pathlib.Path(PAYLOAD_SRC / "mod/cluster_map_aa_greenmenu")
    shutil.copytree(src, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    shutil.copyfile(PAYLOAD_SRC / "mod/custom.sh", "/fs/sda0/mod/custom.sh")
    # unit views
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    sys_prod = "etc/eso/production/smartphone_integrator.json"
    json_cfg = (
        "{\n"
        ' "children": {\n'
        '  "gal": {\n'
        '   "envs":[]\n'
        "  }\n"
        " }\n"
        "}\n")
    for v in SYS_VIEWS:
        car.stage(v, sys_prod, json_cfg)
    for v in (APP_VIEWS[0], APP_VIEWS[2], APP_VIEWS[3],
              SYS_VIEWS[0], SYS_VIEWS[2], SYS_VIEWS[3]):
        car.make_read_only(v)


def test_screen_write_never_truncates_live_file(car):
    _stage(car)
    eng = ENGDEFS
    eng.mkdir(parents=True, exist_ok=True)
    LIVE.write_text(PREV_GOOD)

    p = car.run(["sh", CUSTOM])
    out = p.stdout
    # The screen file on the unit is the generated one (with the card path)
    # — not the previous content — and the previous content is in .prev.
    assert LIVE.exists(), f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    live = LIVE.read_text()
    assert "screen ClusterMap" in live, live
    assert PREV_GOOD not in live
    assert PREV.exists(), ".prev missing"
    assert PREV.read_text() == PREV_GOOD, PREV.read_text()(PREV.read_text() == PREV_GOOD)
    # no staging leftovers
    assert not (ENGDEFS / ".cluster-map.new").exists()
    assert not (pathlib.Path(PKG, "greenmenu/.cluster-map.gen")).exists()
    # the installer ran and reached the end through the FQDN view
    assert "Map install: DONE" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert "diag_collect" not in out  # never leaked an error line about the bundle
    assert pathlib.Path(PKG, "diag.txt").exists(), out


def test_bad_generation_leaves_live_file_alone(car):
    _stage(car)
    ENGDEFS.mkdir(parents=True, exist_ok=True)
    LIVE.write_text(PREV_GOOD)
    # a broken template: exists but EMPTY (generation -> empty file)
    TPL.write_text("")
    p = car.run(["sh", CUSTOM])
    out = p.stdout
    assert "current screen file untouched" in out, \
        f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert LIVE.read_text() == PREV_GOOD, \
        f"live file was rewritten despite the failed generation:\n{LIVE.read_text()}"


def test_missing_template_uses_prebuilt_and_still_keeps_prev(car):
    _stage(car)
    ENGDEFS.mkdir(parents=True, exist_ok=True)
    LIVE.write_text(PREV_GOOD)
    TPL.unlink()
    p = car.run(["sh", CUSTOM])
    out = p.stdout
    assert "screen ClusterMap" in LIVE.read_text(), f"--stdout--\n{out}"
    assert PREV.exists() and PREV.read_text() == PREV_GOOD
    assert "Map install: DONE" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert pathlib.Path(PKG, "diag.txt").exists()
