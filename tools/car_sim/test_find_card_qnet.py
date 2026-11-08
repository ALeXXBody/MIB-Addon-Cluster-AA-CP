"""find_card resolves the card through the spellings the owner's unit
actually shows — the FQDN QNET view included — and a read-only card view
can no longer stop the discovery itself."""
import pathlib
import shutil

# Source of truth in THIS repo; the ZIP ships it as mod/cluster_aa.
PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")

COMMON_SRC = PAYLOAD_SRC / "greenmenu/common.sh"


def _stage(card="/fs/sda0", ro=False):
    dst = pathlib.Path(card, "mod/cluster_aa")
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    _ = ro


def _sh(code):
    return ["sh", "-c", code]


def test_card_found_via_local_mount_point(car):
    """MHI2 prints the sd line FQDN/dev/... on /fs/sda0; the mount table's
    mount POINT is what find_card ends up using, so the payload must resolve
    from there. The QNET abbreviations are fallbacks, never requirements."""
    car.mount_views(rw=["/fs/sda0"])
    _stage("/fs/sda0")
    p = car.run(_sh('. /fs/sda0/mod/cluster_aa/greenmenu/common.sh; '
                    'echo "PKG=$PKG"; echo "VOLUME=$VOLUME"'))
    assert "PKG=/fs/sda0/mod/cluster_aa" in p.stdout, p.stdout
    assert "VOLUME=/fs/sda0" in p.stdout, p.stdout
    assert "ClusterMap folder not found" not in p.stdout, p.stdout


def test_no_card_anywhere_reports_not_found(car):
    """A console whose GEM script can't find any card: the greenmenu code
    prints the not-found explanation and leaves without creating anything."""
    lone = pathlib.Path("/sim/lone")
    lone.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(COMMON_SRC, lone / "common.sh")
    p = car.run(["sh", str(lone / "common.sh")], expect_rc=None)
    assert "ClusterMap folder not found" in p.stdout, \
        f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}"


def test_read_only_card_view_is_not_a_problem_and_still_discovers(car):
    """A card view with a blocked write probe (the console cannot make the
    card writable from this node): discovery STILL succeeds and the console
    explains the card state — installs no longer depend on the card being
    writable at all."""
    car.mount_views(rw=["/fs/sda0"])
    _stage("/fs/sda0")
    car.make_read_only("/fs/sda0")  # blocks the card's write probe
    p = car.run(_sh('. /fs/sda0/mod/cluster_aa/greenmenu/common.sh; '
                    'echo "PKG=$PKG"'), expect_rc=None)
    out = p.stdout
    assert "PKG=/fs/sda0/mod/cluster_aa" in out, \
        f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    # The card is never written, so a read-only view is NOT a problem and
    # must not be reported as one (the payload does not care about the
    # card's write state at all).
    assert "READ-ONLY" not in out and "PROBLEM" not in out, out
