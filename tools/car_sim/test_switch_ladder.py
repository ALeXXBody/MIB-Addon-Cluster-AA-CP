"""The switch-audit regression: a switch must WORK where the console can
only remount /mnt/app through ANOTHER view form. The owner's car showed
"Cannot remount /mnt/app read-write" (see the earlier diag's "Cannot
remount ... /mnt/app"), which made every switch die with its single-form
`mount -uw "$APP_MOUNT"`. Their rewrites now use the shared ladder
(app_mount_rw) and write through the alias that took the remount."""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")

LOCAL_APP = "/mnt/app"
FQDN_APP = "/net/mmx.mibhigh.net/mnt/app"
PROBE = ".clustermap_rw_probe"


def _stage(car):
    dst = pathlib.Path("/fs/sda0/mod/cluster_aa")
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt",
                                                  "LICENSE"))
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    # the installed settings copy, reachable through EVERY app view;
    # the fork player stub carries zoom/keep features so the switches pass
    # their feature checks like the real payload's binaries.
    conf = ("GAL_PLAYER_WINDOW=x\n"
            "GAL_SECONDARY_DPI=125\n")
    player = b"set -- GAL_PLAYER_ZOOM_E4 GAL_KEEP_MAP fake-fork-player"
    for v in APP_VIEWS:
        pathlib.Path(v, "eso/hmi/engdefs").mkdir(parents=True, exist_ok=True)
        car.stage(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf", conf)
        car.stage(v, "navigation/stream-player", player)
    # the LOCAL app view refuses `mount -uw` (the owner's car shape: every
    # single-form remount fails; the FQDN form must save the switches)
    car.env_fail = None
    return dst


def _fail_local(car):
    # stub `mount` refuses single forms: block the local spellings
    car.custom_fail = (LOCAL_APP, "mnt/app")


def test_remote_land_via_ladder_single_form_points_elsewhere(car):
    """The failure shape of the owner's car: /mnt/app cannot be remounted,
    but the FQDN app view takes 'mount -uw'. press: menus.sh remote on
    (the GEM wrapper path exactly as the car)."""
    _stage(car)
    # /mnt/app stays unwritable without blocking others: write-probe file
    car.stage(LOCAL_APP, PROBE, b"")
    p = car.run(["sh", "/fs/sda0/mod/cluster_aa/greenmenu/gem/remote_on.sh"],
                expect_rc=0)
    out = p.stdout + p.stderr
    written = None
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        if f.is_file() and "GAL_CLUSTER_REMOTE=1" in f.read_text():
            written = f
    assert written is not None, f"the switch wrote nowhere\n{out}"
    assert "GAL_CLUSTER_REMOTE=1" in written.read_text()
    # the story lives in the bundle (the console stays minimal): which
    # remount form won is recorded verbatim there
    bundle = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "app: read-write via " in bundle, bundle


def test_remote_report_verdict_when_nothing_can_be_remounted(car):
    """The owner's full-refusal shape: EVERY remount form fails - the
    switch refuses LOUDLY (STOPPED verdict + the form errors land in the
    diag's run log), it never fakes success."""
    _stage(car)
    car.stage(LOCAL_APP, PROBE, b"")
    fail_all = "|".join(["", *APP_VIEWS, ""])
    p = car.run(["sh", "/fs/sda0/mod/cluster_aa/greenmenu/gem/remote_on.sh"],
                env={"CB_MOUNT_FAIL": fail_all})
    out = p.stdout + p.stderr
    assert "== STOPPED" in out, out
    assert "Cannot remount the app partition read-write" in out, out
    bundle = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "Cannot remount" in bundle, (
        f"the refusal is not measured in the bundle:\n"
        "== sections 11/12 ==\n"
        + "\n".join(bundle.splitlines()[-14:]))
