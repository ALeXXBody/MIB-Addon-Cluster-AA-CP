"""ensure_write_dir picks the card when writable and /tmp when it is not,
and records the home for uninstall."""
import pathlib
import re
import shutil

ENABLE = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/"
                      "mod/cluster_map_aa_greenmenu/enable_hook.sh")


def _extract():
    s = ENABLE.read_text()
    m = re.search(r"ensure_write_dir\(\) \{.*?\n\}\n", s, re.S)
    assert m, "ensure_write_dir() not found in enable_hook.sh"
    return m.group(0)


def test_card_writable_wins(car):
    car.stage("/fs/sda0", "mod/cluster_map_aa_greenmenu/enable_hook.sh",
              ENABLE.read_text())
    fn = "/fs/sda0/.ewd_fn.sh"
    pathlib.Path(fn).write_text(_extract())
    p = car.run(["bash", "-c",
                 f'CARD_ROOT=/fs/sda0; . {fn}; ensure_write_dir; '
                 'echo "WRITE_HOME=$WRITE_HOME"; '
                 'echo "ORIGINAL=$ORIGINAL"; '
                 'cat /fs/sda0/last_install_paths.txt'],
                expect_rc=0)
    out = p.stdout
    assert "WRITE_HOME=/fs/sda0" in out, f"--stdout--\n{out}\n--stderr--\n{p.stderr}"
    assert "ORIGINAL=/fs/sda0/backups/smartphone_integrator.json.original" in out, out
    assert "WRITE_HOME=/fs/sda0" in pathlib.Path("/fs/sda0/last_install_paths.txt").read_text(), out


def test_card_ro_falls_back_to_tmp_and_records(car):
    """A card root the console cannot even see (no card): the backup home
    falls back to /tmp and the home record lands there too — the /tmp
    marker path, so uninstall still finds BOTH sources."""
    fn = "/sim/ewd_fn.sh"
    pathlib.Path(fn).write_text(_extract())
    # CARD_ROOT absent entirely: /fs/sda0 was never mounted in this test.
    p = car.run(["bash", "-c",
                 'CARD_ROOT=/fs/sda0; . /sim/ewd_fn.sh; ensure_write_dir 2>/dev/null; '
                 'echo "WRITE_HOME=$WRITE_HOME"; echo "ORIGINAL=$ORIGINAL"; '
                 'cat /tmp/clustermap_last_paths '
                 '2>/dev/null || echo "NO-CARD-MARKER"'],
                expect_rc=0)
    out = p.stdout
    assert "WRITE_HOME=/tmp/clustermap_unit" in out, out
    assert "ORIGINAL=/tmp/clustermap_unit/backups/smartphone_integrator.json.original" in out, out
    marker = pathlib.Path("/tmp/clustermap_last_paths")
    assert marker.exists(), out
    txt = marker.read_text()
    assert "BACKUP_DIR=/tmp/clustermap_unit/backups" in txt
    assert "LOG_DIR=/tmp/clustermap_unit/logs" in txt
    assert "WRITE_HOME=/tmp/clustermap_unit" in txt
    assert pathlib.Path("/tmp/clustermap_unit/backups").is_dir(), out
