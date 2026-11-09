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


def test_position_preset_writes_insets_through_a_working_view(car):
    """Position = the inset lever (content box placement), same contract
    as every switch: probe-blocked local view cannot stop it, the write
    lands through the spelling that took the remount, and the console
    verdict says what happens next."""
    _stage(car)
    car.stage(LOCAL_APP, PROBE, b"")
    p = car.run(["sh", "/fs/sda0/mod/cluster_aa/greenmenu/gem/position_higher.sh"],
                expect_rc=0)
    childlog = car.run(["cat", "/tmp/cm_menu_position.log"])
    written = None
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        if f.is_file() and "GAL_SECONDARY_INSETS=32,48,127,127" in f.read_text():
            written = f
    assert written is not None, (
        f"no position write landed\n{p.stdout}\n{p.stderr}\n"
        f"--child log--\n{childlog.stdout}{childlog.stderr}")
    bundle = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "Position: higher" in bundle, bundle


def test_position_standard_restores_the_shipped_insets(car):
    _stage(car)
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        f.write_text("GAL_SECONDARY_INSETS=32,48,90,100\n")
    car.run(["sh", "/fs/sda0/mod/cluster_aa/greenmenu/gem/position_standard.sh"],
            expect_rc=0)
    hit = False
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        if "GAL_SECONDARY_INSETS=40,40,127,127" in f.read_text():
            hit = True
    assert hit, "standard did not restore the shipped insets"


def test_position_clears_an_old_ui_config_override(car):
    """A remembered arm-window preset (GAL_SECONDARY_UI_CONFIG_HEX) replaces
    the insets AND theme entirely: a Position press must clear it, or the
    preset silently does nothing (found on the owner's unit: hex preset
    from a Turn-card clear press was still committed)."""
    _stage(car)
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        f.write_text("GAL_PLAYER_WINDOW=1010x376\n"
                     "GAL_SECONDARY_INSETS=40,40,127,127\n"
                     "GAL_SECONDARY_UI_CONFIG_HEX=5a041202083c\n"
                     "GAL_SECONDARY_UI_THEME=2\n")
    p = car.run(["sh", "/fs/sda0/mod/cluster_aa/greenmenu/gem/position_lower.sh"],
                expect_rc=0)
    hit = None
    for v in APP_VIEWS:
        f = pathlib.Path(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf")
        t = f.read_text() if f.is_file() else ""
        if "GAL_SECONDARY_INSETS=48,32,127,127" in t:
            hit = t
    assert hit is not None, f"no inset write\n{p.stdout}\n{p.stderr}"
    assert "GAL_SECONDARY_UI_CONFIG_HEX" not in hit, "the override survived"
    assert "GAL_SECONDARY_UI_THEME=2" in hit, "theme preset lost"
