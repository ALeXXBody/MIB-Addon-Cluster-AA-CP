"""The card copy of diag.txt must never be a silent maybe.

v0.4.21 shipped a best-effort `cp ... 2>/dev/null`: if the unit's card view
was read-only (the FAT dirty bit after an unsafe eject) the copy failed and
NOTHING said so — the owner then hunted a file on the card that was never
written (the report that started this round). Two properties are pinned:

  1. when the card accepts the copy, the console NAMES the file (verified:
     a checksum-verified copy through the first spelling that takes bytes);
  2. when the card refuses, the console says NOT WRITTEN and prints the
     tuning facts — a photo of that screen is still enough to fine-tune.
"""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS, CARD_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")
REPO_MOD = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/mod")
PKG_ALT = "/net/mmx/fs/sda0/mod/cluster_aa"
PKG = "/fs/sda0/mod/cluster_aa"


def _stage_payload(dst, armed=False):
    path = pathlib.Path(dst)
    path.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, path, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt",
                                                  "LICENSE"))
    if armed:
        (path / "HOOK_ARMED").write_text("")
    return path


def _block_writes(payload_dir):
    """Emulate a read-only FAT payload folder for THIS script's own probes:
    both the card-write probe and the destination file are directories, so
    every write attempt fails deterministically while reads keep working."""
    (pathlib.Path(payload_dir) / ".clustermap_card_probe").mkdir(exist_ok=True)
    (pathlib.Path(payload_dir) / "diag.txt").mkdir(exist_ok=True)


def _stage_unit(car):
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-stock-player-bytes")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, "etc/eso/production/smartphone_integrator.json",
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\\n }\n}\n'
                  .replace("\\n", "\n"))


def test_card_read_only_is_said_out_loud_with_the_facts(car):
    _stage_unit(car)
    _stage_payload(PKG, armed=True)
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    _block_writes(PKG)
    # the card ROOT refuses too (an entire read-only FAT volume)
    (pathlib.Path("/fs/sda0") / ".clustermap_card_probe").mkdir(exist_ok=True)
    (pathlib.Path("/fs/sda0") / "diag.txt").mkdir(exist_ok=True)
    p = car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "card copy:" in out, f"the console stayed silent about the card\n{out}"
    assert "NOT WRITTEN" in out, f"\n{out}"
    # a photo of the console is still enough to fine-tune the picture
    assert "GAL_PLAYER_WINDOW=" in out, out
    # and the diag bundle still exists ON THE UNIT
    assert b"1 unit and firmware" in pathlib.Path(
        "/tmp/clustermap_diag/diag.txt").read_bytes()
    # direct call, for the record
    p2 = car.run(["sh", f"{PKG}/greenmenu/diag_collect.sh", "-v"], expect_rc=0)
    print("RAW_COLLECTOR_OUT:", repr(p2.stdout))
    assert "card copy:" not in p2.stdout or "NOT WRITTEN" in p2.stdout


def test_copy_falls_through_to_a_writable_spelling_and_is_named(car):
    _stage_unit(car)
    _stage_payload(PKG, armed=True)
    _stage_payload(PKG_ALT, armed=True)
    # the payload folder reachable through the OTHER spelling is read-only;
    # the writable one (/fs/sda0) must be found and NAMED on the console.
    _block_writes(PKG_ALT)
    p = car.run(["sh", "-c",
                 "sh /net/mmx/fs/sda0/mod/cluster_aa/greenmenu/"
                 "diag_collect.sh -v"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "card copy:" in out, out
    assert "NOT WRITTEN" not in out, out
    copied = pathlib.Path(PKG, "diag.txt")
    assert copied.is_file(), f"\n{out}"
    assert "1 unit and firmware" in copied.read_text()


def test_every_run_narrates_the_card_copy_on_success(car):
    _stage_unit(car)
    _stage_payload(PKG, armed=True)
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    p = car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "card copy:" in out, f"missing the delivery line\n{out}"
    assert f"/fs/sda0/mod/cluster_aa/diag.txt" in out, out
    assert "NOT WRITTEN" not in out, out
    copied = pathlib.Path(PKG, "diag.txt")
    assert copied.is_file() and "1 unit and firmware" in copied.read_text()
    # nothing named the copy when there is nothing to name (no silent claims)
    if pathlib.Path("/tmp/clustermap_diag/LAST_CARD_PATH").exists():
        assert pathlib.Path("/tmp/clustermap_diag/LAST_CARD_PATH"
                            ).read_text().strip() == \
            f"/fs/sda0/mod/cluster_aa/diag.txt"


def test_blocked_payload_folder_falls_back_to_the_card_root(car):
    """The card itself accept writes, but the payload folder refuses: the
    copy may still land at the card ROOT, and the console must name IT."""
    _stage_unit(car)
    _stage_payload(PKG, armed=True)
    shutil.copyfile(REPO_MOD / "custom.sh", "/fs/sda0/mod/custom.sh")
    _block_writes(PKG)
    p = car.run(["sh", "/fs/sda0/mod/custom.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "card copy:   /fs/sda0/diag.txt" in out, out
    assert "NOT WRITTEN" not in out, out
    root_copy = pathlib.Path("/fs/sda0", "diag.txt")
    assert root_copy.is_file() and "1 unit and firmware" in root_copy.read_text()
