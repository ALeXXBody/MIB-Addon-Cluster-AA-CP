"""The single diagnostic file on the card (diag.txt) — written by every
install/uninstall/settings run, and carrying everything needed to
diagnose + fine-tune remotely. This is the file the owner sends."""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

# Source of truth in THIS repo; the ZIP ships it as mod/cluster_aa.
PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")

REPO_MOD = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/mod")
PKG = "/fs/sda0/mod/cluster_aa"
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
    # quiet console: the outcome line exists, the pages do not. An unarmed
    # run is honestly reported as STAGED, not as a live map.
    assert ("Map install: FAILED" in out or "Map install: DONE" in out
            or "Staged only (not armed)" in out), out
    n = len([l for l in out.splitlines() if l.strip()])
    assert n < 20, f"console is too verbose again ({n} lines)\n{out}"

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


# ---------------------------------------------------------------------------
# EVERY exit path must leave a diagnostic file. The owner's rule: if a run
# stops, one file from the card explains why — even when the run dies before
# the install step (the v0.4.19 failure that produced no diag at all).
# ---------------------------------------------------------------------------

def test_early_screen_failure_still_writes_diag_with_reason(car):
    _stage(car, armed=True)
    # break the template generation: armed run reaches the screen step, the
    # generation produces an EMPTY file, the run must stop safely.
    tpl = pathlib.Path(PKG, "greenmenu/cluster-map.template.esd")
    tpl.write_text("")
    live = pathlib.Path(APP_VIEWS[1], "eso/hmi/engdefs/cluster-map.esd")
    live.parent.mkdir(parents=True, exist_ok=True)
    live.write_text("PREVIOUS-GOOD-SCREEN\n")

    p = car.run(["sh", CUSTOM], expect_rc=None)
    out = p.stdout
    assert p.returncode != 0, f"expected the run to stop, got rc=0\n{out}"
    assert "current screen file untouched" in out, out
    # the unit's live screen is untouched
    assert live.read_text() == "PREVIOUS-GOOD-SCREEN\n"
    # and the reason is in the ONE file the owner sends
    diag = pathlib.Path("/tmp/clustermap_diag/diag.txt")
    assert diag.exists(), f"no diag bundle after an early failure\n{out}"
    txt = diag.read_text()
    assert "generated file is EMPTY" in txt, txt[-2000:]
    assert "custom.sh console" in txt, txt[-2000:]


def test_no_payload_on_card_still_leaves_a_diag(car):
    # custom.sh placed somewhere runnable, but NO card content at all.
    custom = pathlib.Path("/sim/custom.sh")
    custom.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(REPO_MOD / "custom.sh", custom)
    p = car.run(["sh", str(custom)], expect_rc=None)
    out = p.stdout
    assert p.returncode != 0, out
    assert "not" in out and "found on the SD card" in out, out
    diag = pathlib.Path("/tmp/clustermap_diag/diag.txt")
    assert diag.exists(), f"no diag bundle when the card payload is missing\n{out}"
    txt = diag.read_text()
    assert "payload" in txt and "not" in txt, txt
