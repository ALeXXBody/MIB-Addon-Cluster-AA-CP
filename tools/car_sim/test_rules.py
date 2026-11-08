"""THE TWO OWNER RULES, enforced offline (this is the regression gate):

Rule 1 — do not break the unit firmware:
    an install that does not ARM leaves gal's supervisor config
    byte-identical, leaves the unit's stream-player untouched, and never
    edits lsd.sh; even an ARMED run keeps the stock player beside the live
    one, and the uninstall restores the stock bytes.

Rule 2 — do not mess with the GEM:
    an install that does not ARM leaves engdefs byte-identical (no screen
    file, no staging leftovers, z_Launcher untouched).

These are hard assertions on the REAL scripts, not documentation.
"""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS
import test_hook_lifecycle as base

PAYLOAD_SRC = base.PAYLOAD_SRC
PKG = base.PKG
CUSTOM = "/fs/sda0/mod/custom.sh"
ENGDEFS = pathlib.Path(APP_VIEWS[1], "eso/hmi/engdefs")
CFG_KEY = "etc/eso/production/smartphone_integrator.json"
PLAYER_KEY = "navigation/stream-player"


def _stage(car, armed=False, custom=False):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    if custom:
        shutil.copyfile(PAYLOAD_SRC.parent / "custom.sh", "/fs/sda0/mod/custom.sh")
    if armed:
        (dst / "HOOK_ARMED").write_text("")
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-stock-player-bytes")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    json_cfg = (
        "{\n"
        ' "children": {\n'
        '  "gal": {\n'
        '   "envs":[]\n'
        "  }\n"
        " }\n"
        "}\n")
    for v in SYS_VIEWS:
        car.stage(v, CFG_KEY, json_cfg)
    for v in (APP_VIEWS[0], APP_VIEWS[2], APP_VIEWS[3],
              SYS_VIEWS[0], SYS_VIEWS[2], SYS_VIEWS[3]):
        car.make_read_only(v)


def test_rule1_unarmed_install_changes_no_firmware_bytes(car):
    """The unarmed install must leave the firmware-affecting files byte-identical."""
    _stage(car)
    sysfile = pathlib.Path(SYS_VIEWS[1], CFG_KEY)
    player = pathlib.Path(APP_VIEWS[1], PLAYER_KEY)
    before_cfg = sysfile.read_bytes()
    before_player = player.read_bytes()

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    assert p.returncode == 0, f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"

    assert sysfile.read_bytes() == before_cfg, \
        "the unarmed install wrote into gal's supervisor config (Rule 1)"
    assert player.read_bytes() == before_player, \
        "the unarmed install replaced the unit's stream-player (Rule 1)"
    assert not pathlib.Path(APP_VIEWS[1], "navigation/stream-player.aacluster-original").exists()
    # lsd.sh has no NavActiveIgnore line added
    lsd = pathlib.Path(APP_VIEWS[1], "eso/hmi/lsd/lsd.sh")
    assert not (lsd.exists() and "NavActiveIgnore.jar" in lsd.read_text()), \
        "the unarmed install edited the Java boot script (Rule 1)"


def test_rule2_unarmed_install_touches_no_gem_file(car):
    """No engdefs write of any kind without arming."""
    _stage(car, custom=True)
    ENGDEFS.mkdir(parents=True, exist_ok=True)
    sentinel = "STOCK-GEM-FILES-ARE-LONGER-GONE\n"
    for name in ("production.esd", "Main.esd", "z_Launcher-sda0.esd"):
        (ENGDEFS / name).write_text(sentinel)
    before = {n: (ENGDEFS / n).read_bytes()
              for n in ("production.esd", "Main.esd", "z_Launcher-sda0.esd")}

    p = car.run(["sh", CUSTOM], expect_rc=None)
    out = p.stdout
    assert p.returncode == 0, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    # The unarmed run is SILENT about arming on the console (owner's rule:
    # minimal GEM output). The state lives in diag.txt, not on the screen.
    assert "NOT registered" not in out, f"--stdout--\n{out}"
    assert not (ENGDEFS / "cluster-map.esd").exists(), "GEM screen registered unarmed (Rule 2)"
    assert not (ENGDEFS / "cluster-map.esd.prev").exists()
    assert not (ENGDEFS / ".cluster-map.new").exists()
    for name, data in before.items():
        assert (ENGDEFS / name).read_bytes() == data, f"{name} changed (Rule 2)"


def test_rule1_armed_install_backs_up_and_uninstall_restores_the_player(car):
    """Armed run: stock player preserved as .aacluster-original; uninstall
    puts the stock bytes back byte-identically."""
    _stage(car, armed=True)
    player = pathlib.Path(APP_VIEWS[1], PLAYER_KEY)
    before = player.read_bytes()
    sidecar = pathlib.Path(APP_VIEWS[1], "navigation/stream-player.aacluster-original")

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    assert p.returncode == 0, f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"
    assert sidecar.exists(), "armed install did not keep the stock player copy"
    assert sidecar.read_bytes() == before, "sidecar is not the stock player"
    assert player.read_bytes() != before, "armed install did not place our player"

    q = car.run(["sh", f"{PKG}/disable_hook.sh"], expect_rc=None)
    assert q.returncode == 0, f"--stdout--\n{q.stdout}\n--stderr--\n{q.stderr}"
    assert player.read_bytes() == before, \
        "uninstall did not restore the unit's stock player byte-identically"
    assert not sidecar.exists(), "the sidecar must be removed after the restore"


def test_unarmed_run_on_an_already_live_unit_says_so(car):
    """An unarmed run must not claim 'staged only' when the hook is ALREADY
    live from an earlier armed install: it says 'already live, unchanged'
    and touches nothing."""
    _stage(car, custom=True)
    live_cfg = (
        "{\n"
        ' "children": {\n'
        '  "gal": {\n'
        '   "envs":[\n'
        '    "LD_PRELOAD=/eso/lib/gal_dualscreen/libgal_hook.so"\n'
        '   ]\n'
        "  }\n"
        " }\n"
        "}\n")
    sysfile = pathlib.Path(SYS_VIEWS[1], CFG_KEY)
    sysfile.write_text(live_cfg)

    p = car.run(["sh", CUSTOM], expect_rc=None)
    assert p.returncode == 0, f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"
    assert "already live" in p.stdout, p.stdout
    assert "Staged only" not in p.stdout, p.stdout
    assert sysfile.read_text() == live_cfg, \
        "an unarmed run changed an already-live supervisor config"
