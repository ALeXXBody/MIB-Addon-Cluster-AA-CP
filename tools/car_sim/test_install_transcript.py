"""The v0.7.29-31 install killer: transcript redirected onto the read-only
card. The shell refuses the redirect and NEVER runs enable_hook.sh, so the
unit keeps whatever old hook an earlier install left staged. The old sim
never caught this because its card was writable -- this test makes the card
root read-only, exactly the owner's FAT card shape (§12 of the diag).
"""
import pathlib
import shutil

from conftest import APP_VIEWS, REPO, SYS_VIEWS

PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"


def _stage_installable(car):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "HOOK_ARMED").write_text("")
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        if pathlib.Path(v).exists():
            car.stage(v, "navigation/stream-player", b"unit-player-stub")
            car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    json_cfg = ('{\n "children": {\n  "gal": {\n   "envs":[]\n'
                '  }\n }\n}\n')
    for v in SYS_VIEWS:
        car.stage(v, "etc/eso/production/smartphone_integrator.json", json_cfg)


def test_install_runs_when_the_card_root_is_read_only(car):
    _stage_installable(car)
    # Car shape: writing a NEW file at the card root refuses, while the
    # payload subfolder and the unit's own partitions stay writable.
    car.make_root_read_only("/fs/sda0")

    p = car.run(["sh", f"{PKG}/greenmenu/install.sh"], expect_rc=None)
    out = p.stdout
    assert "CLUSTERMAP_INSTALL_OK" in out, \
        f"install failed on a read-only card:\n{out}\n{p.stderr}"
    assert "CLUSTERMAP_INSTALL_FAILED" not in out, out
    assert ("Read-only file system" not in out), out

    # The transcript went to RAM, not to the card root.
    log = pathlib.Path("/tmp/clustermap_install.log")
    assert log.exists(), f"no transcript in RAM:\n{out}"
    assert log.stat().st_size > 0, "the transcript is empty"
    assert not pathlib.Path(PKG, "install.log").exists(), \
        "the install still tried to write onto the read-only card"

    # The real proof: enable_hook.sh actually RAN (it creates the marker
    # and stages the hook into the unit's app view).
    assert pathlib.Path("/tmp/clustermap_last_paths").exists(), \
        f"enable_hook.sh never ran:\n{out}"
    staged = pathlib.Path(APP_VIEWS[0], "eso/lib/gal_dualscreen/libgal_hook.so")
    assert staged.exists(), f"hook not staged on the unit:\n{out}"

    # Save-logs must report the RAM transcript, not "absent".
    car.run(["sh", f"{PKG}/greenmenu/diag_collect.sh"], expect_rc=None)
    diag = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "install transcript, from RAM" in diag, diag[-2500:]
    assert "no install has run on this boot" not in diag
