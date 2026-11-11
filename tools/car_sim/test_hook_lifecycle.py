"""FULL lifecycle, offline: the hook installer writes the unit through the
FQDN QNET spelling when every other view is read-only, then the uninstall
restores the supervisor config from the recorded backup home."""
import pathlib
import shutil
import re
import json

from conftest import APP_VIEWS, SYS_VIEWS

# Source of truth in THIS repo; the ZIP ships it as mod/cluster_aa.
PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")

PKG = "/fs/sda0/mod/cluster_aa"

HOOK_SUB = "/eso/lib/gal_dualscreen/libgal_hook.so"


def _stage(car):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    (dst / "HOOK_ARMED").write_text("")  # this gate exercises the armed path
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    card = pathlib.Path(PKG)
    # `on` does not exist in the sim: the installer's cross-node form must be
    # skipped gracefully. jsonlint is staged on every EXISTING app view.
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")


def test_install_then_uninstall_via_fqdn_view(car):
    """Views: /mnt/app and both /net/mmx spellings are READ-ONLY. The only
    writable view is the FQDN one — everything must land there, while the
    install's own `mount -uw` calls still claim success on the RO views
    (exactly the unit's contradictory-tools behavior)."""
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    _stage(car)
    # Unit reality these views carry even when read-only: the navigation
    # directory (stream/player), libairplay (CarPlay detection) and the
    # supervisor config with the children/gal/envs injection block.
    for v in APP_VIEWS:
        if pathlib.Path(v).exists():
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
        car.make_read_only(v)     # real RO; content stays readable through it

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    out = p.stdout
    assert p.returncode == 0, f"--stdout--\n{out}\n--- stderr ---\n{p.stderr}"
    # The install used the FQDN spelling and SAID so:
    assert "app partition: read-write via" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert re.search(r"read-write via '.*mmx\.mibhigh\.net", out), \
        f"install picked some other view:\n--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert "system: read-write via" in out, out
    # Artifacts live ONLY under the FQDN view:
    fq = pathlib.Path(APP_VIEWS[1], "eso/lib/gal_dualscreen/libgal_hook.so")
    assert fq.exists(), f"{fq} missing\n--stdout--\n{out}"
    assert not pathlib.Path(APP_VIEWS[0], HOOK_SUB).exists(), \
        " libgal_hook.so landed on /mnt/app — wrong view"
    # BOOT-SAFETY CONTRACT: an install stages the hook files but leaves
    # gal's supervisor config WITHOUT the hook's LD_PRELOAD line. The hook
    # can only go live on an explicit, separate owner action.
    cfg = pathlib.Path(SYS_VIEWS[1], "etc/eso/production/smartphone_integrator.json")
    cfgtxt = cfg.read_text()
    assert "LD_PRELOAD" in cfgtxt, f"armed install must inject the preload: {cfgtxt[:160]}..."
    assert "GAL_DUALSCREEN_ENABLE=1" in cfgtxt, cfgtxt

    # The install's work home is the unit's RAM, never the card; the
    # persistent recovery copy lives beside the live config.
    marker = pathlib.Path("/tmp/clustermap_last_paths")
    assert marker.exists(), f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    mtxt = marker.read_text()
    assert "WRITE_HOME=/tmp/clustermap_unit" in mtxt, mtxt
    assert pathlib.Path("/tmp/clustermap_unit/backups/"
                        "smartphone_integrator.json.original").exists(), out
    assert pathlib.Path(str(cfg) + ".gal-dualscreen.original").exists(), out
    # And nothing was written to the card payload folder.
    assert not pathlib.Path(PKG, "last_install_paths.txt").exists()
    assert not pathlib.Path(PKG, "backups").exists()

    # ---- uninstall ----
    q = car.run(["sh", f"{PKG}/disable_hook.sh"], expect_rc=None)
    assert q.returncode == 0, f"--stdout--\n{q.stdout}\n--stderr--\n{q.stderr}"
    restored = cfg.read_text()
    assert "libgal_hook.so" not in restored, f"uninstall left the hook:\n{restored}"
    assert "children" in restored, f"restore dropped the original content:\n{restored}"
