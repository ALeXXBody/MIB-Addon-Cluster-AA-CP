"""The single diagnostic file on the card (diag.txt) — written by every
install/uninstall/settings run, and carrying everything needed to
diagnose + fine-tune remotely. This is the file the owner sends."""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")
REPO_MOD = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/mod")
PKG = "/fs/sda0/mod/cluster_map_aa_greenmenu"
CUSTOM = "/fs/sda0/mod/custom.sh"


def _stage(car, armed=False):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    if armed:
        (dst / "HOOK_ARMED").write_text("")
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-stock-player-bytes")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, "etc/eso/production/smartphone_integrator.json",
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')
    for v in (APP_VIEWS[0], APP_VIEWS[2], APP_VIEWS[3],
              SYS_VIEWS[0], SYS_VIEWS[2], SYS_VIEWS[3]):
        car.make_read_only(v)


def test_unarmed_run_writes_the_diag_bundle(car):
    _stage(car)
    p = car.run(["sh", CUSTOM], expect_rc=0)
    out = p.stdout
    # quiet console: the run's outcome lines exist, the pages do not
    assert "Map install: FAILED" in out or "Map install: DONE" in out
    assert len([l for l in out.splitlines() if l.strip()]) < 80, \
        f"console is too verbose again ({len(out.splitlines())} lines)"

    diag = pathlib.Path(PKG, "diag.txt")
    assert diag.exists()
    txt = diag.read_text()
    for section in ("1 unit and firmware", "2 payload files", "3 card views",
                    "4 unit partition views", "5 arm state", "6 engdefs listing",
                    "7 installed settings", "8 supervisor config",
                    "10 install home record", "12 full log"):
        assert section in txt, f"diag bundle missing section: {section}"
    assert "HOOK_ARMED marker: absent" in txt
    assert len(txt) < 64 * 1024, "diag bundle is too large to send casually"
    # a previous bundle is kept when a second run happens
    car.run(["sh", CUSTOM], expect_rc=0)
    prev = pathlib.Path(PKG, "diag.txt.prev")
    assert prev.exists(), "diag.txt.prev missing"


def test_diag_sections_carry_fine_tune_facts(car):
    _stage(car, armed=True)
    car.run(["sh", CUSTOM], expect_rc=0)
    txt = pathlib.Path(PKG, "diag.txt").read_text()
    # the fine-tune facts the owner needs for the picture-quality work:
    assert "GAL_PLAYER_WINDOW=800x480" in txt, txt
    assert "GAL_SECONDARY_DPI=125" in txt
    assert "GAL_SECONDARY_INSETS=40,40,127,127" in txt
    assert "HOOK_ARMED marker: present" in txt
    assert "hook preloaded into gal (config carries LD_PRELOAD): YES" in txt
