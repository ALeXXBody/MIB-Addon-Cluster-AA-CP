"""The mount ladder picks a view that is PROVEN writable through its own
spelling — and reports the winning form."""
import pathlib
import shutil

from conftest import APP_VIEWS

REPO_LIB = ("/tmp/opencode/mib2/mib-mod-repo/"
            "mod/cluster_map_aa_greenmenu/scripts/lib_app_mount.sh")
DST = "/fs/sda0/mod/cluster_map_aa_greenmenu/scripts/lib_app_mount.sh"


def _stage_lib():
    p = pathlib.Path(DST)
    p.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(REPO_LIB, p)


def _sh(code):
    return ["sh", "-c", ". /fs/sda0/mod/cluster_map_aa_greenmenu/scripts/lib_app_mount.sh; " + code]


def test_local_view_writable_wins(car):
    _stage_lib()
    car.mkdir_views(APP_VIEWS)
    p = car.run(_sh('app_mount_rw; echo "APP_RW=$APP_RW"; echo "FORM=$APP_LADDER_FORM"'),
                expect_rc=0)
    assert "APP_RW=/mnt/app" in p.stdout, f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"
    assert "FORM=mount -uw /mnt/app" in p.stdout


def test_probe_blocked_views_fall_through_to_fqdn(car):
    """The owner's shape: mount succeeds everywhere, but real WRITE probes on
    /mnt/app and the shorthand fail (readonly views) — the ladder must end
    on the ONE view whose write probe succeeded."""
    _stage_lib()
    car.mkdir_views(APP_VIEWS)
    car.stage(APP_VIEWS[0], ".clustermap_rw_probe", b"")
    car.stage(APP_VIEWS[2], ".clustermap_rw_probe", b"")
    p = car.run(_sh('app_mount_rw; echo "APP_RW=$APP_RW"; echo "FORM=$APP_LADDER_FORM"'),
                expect_rc=0)
    assert "APP_RW=/net/mmx.mibhigh.net/mnt/app" in p.stdout, \
        f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"


def test_mount_refusal_views_allow_fqdn(car):
    """The mount -uw refusal class: the stub refuses every spelling except
    the FQDN view (CB_MOUNT_FAIL)."""
    _stage_lib()
    car.mkdir_views(APP_VIEWS)
    fail = "|".join(["", *[v for v in APP_VIEWS if v != APP_VIEWS[1]], ""])
    p = car.run(_sh('app_mount_rw; echo "APP_RW=$APP_RW"; echo "FORM=$APP_LADDER_FORM"'),
                env={"CB_MOUNT_FAIL": fail}, expect_rc=0)
    assert "APP_RW=/net/mmx.mibhigh.net/mnt/app" in p.stdout, \
        f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"


def test_ladder_fails_when_all_views_refused(car):
    _stage_lib()
    car.mkdir_views(APP_VIEWS)
    fail = "|".join(["", *APP_VIEWS, ""])
    p = car.run(_sh('if app_mount_rw; then echo "UNEXPECTED-SUCCESS"; '
                    'else echo "FAILED-AS-EXPECTED"; fi'),
                env={"CB_MOUNT_FAIL": fail})
    assert "FAILED-AS-EXPECTED" in p.stdout, p.stdout


def test_pick_view_first_existing(car):
    _stage_lib()
    car.mkdir_views(APP_VIEWS)
    p = car.run(_sh("app_pick_view"), expect_rc=0)
    assert p.stdout.strip() == "/mnt/app", p.stdout


def test_pick_view_falls_through_to_fqdn_when_local_absent(car):
    _stage_lib()
    for v in APP_VIEWS[1:]:
        p = pathlib.Path(v)
        p.mkdir(parents=True, exist_ok=True)
    p = car.run(_sh("app_pick_view"), expect_rc=0)
    assert p.stdout.strip() == "/net/mmx.mibhigh.net/mnt/app", p.stdout

