"""Greenmenu screens resolve unit files through whatever view spelling the
console can actually address — Status, and the verify manifest path retry."""
import pathlib
import shutil
import textwrap

from conftest import APP_VIEWS, SYS_VIEWS, JSONLINT_SH

# Source of truth in THIS repo; the ZIP ships it as mod/cluster_aa.
PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")

PKG = "/fs/sda0/mod/cluster_aa"


def _stage_payload(car, card="/fs/sda0"):
    dst = pathlib.Path(card, "mod/cluster_aa")
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    return dst


def test_status_reports_present_via_fqdn_view(car):
    """Every unit file lives ONLY under the FQDN view; /mnt/app is absent
    (this console cannot see the old spelling at all). Status must still
    say :present — it used to report 'missing' here (the owner's symptom)."""
    car.mount_views(rw=[APP_VIEWS[1], SYS_VIEWS[1]])
    _stage_payload(car)
    car.stage(APP_VIEWS[1], "eso/lib/gal_dualscreen/libgal_hook.so", b"\x7fELF-stub")
    car.stage(APP_VIEWS[1], "navigation/stream-player", b"stream-player-stub")
    car.stage(APP_VIEWS[1], "eso/lib/libairplay.so", bytes(703688))
    car.stage_jsonlint_all_app_views()
    car.stage(SYS_VIEWS[1], "etc/eso/production/smartphone_integrator.json", '{"a": 1}\n')
    car.stage_version("rcc")
    p = car.run(["sh", f"{PKG}/greenmenu/status.sh"])
    out = p.stdout
    assert f"library: present" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert "player: present" in out, out
    assert "missing" not in out.lower() or "supported: yes" in out, out


def test_verify_manifest_paths_retried_across_views(car):
    """The verify manifest names files under /mnt/app (the spelling the
    installer used); this console addresses them only via FQDN — verify
    must retry each manifest line across the views and report PASS."""
    car.mount_views(rw=[APP_VIEWS[1]])
    _stage_payload(car)
    b = b"payload-bytes-here-00001111"
    real = car.stage(APP_VIEWS[1], "eso/lib/gal_dualscreen/profiles.conf", b)
    ck = car.run(["cksum", str(real)])
    crc, size = ck.stdout.split()[:2]
    manifest = f"/mnt/app/eso/lib/gal_dualscreen/profiles.conf {crc} {size}\n"
    car.stage(APP_VIEWS[1], "eso/lib/gal_dualscreen/verify_manifest.txt", manifest)
    p = car.run(["sh", f"{PKG}/greenmenu/verify.sh"])
    out = p.stdout
    assert "PASS" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert "CHANGED" not in out, out
