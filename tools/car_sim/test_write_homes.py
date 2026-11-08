"""ensure_write_dir NEVER writes the card.

The install work home (backups + logs) is always /tmp/clustermap_unit on the
unit's RAM. The card is treated as read-only media, permanently: our own
writes were what set FAT's dirty bit and produced the phantom "READ-ONLY
card" reports. The persistent config backup that an uninstall needs lives
beside the live config on the unit (its own partition), not here.
"""
import pathlib
import re

ENABLE = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo/"
                      "mod/cluster_map_aa_greenmenu/enable_hook.sh")


def _extract():
    s = ENABLE.read_text()
    m = re.search(r"ensure_write_dir\(\) \{.*?\n\}\n", s, re.S)
    assert m, "ensure_write_dir() not found in enable_hook.sh"
    return m.group(0)


def test_home_is_ram_even_when_card_is_writable(car):
    car.stage("/fs/sda0", "mod/cluster_aa/enable_hook.sh", ENABLE.read_text())
    fn = "/fs/sda0/.ewd_fn.sh"
    pathlib.Path(fn).write_text(_extract())
    p = car.run(["bash", "-c",
                 f'CARD_ROOT=/fs/sda0; . {fn}; ensure_write_dir; '
                 'echo "WRITE_HOME=$WRITE_HOME"; '
                 'echo "ORIGINAL=$ORIGINAL"'],
                expect_rc=0)
    out = p.stdout
    assert "WRITE_HOME=/tmp/clustermap_unit" in out, out
    assert "ORIGINAL=/tmp/clustermap_unit/backups/smartphone_integrator.json.original" in out, out
    # The marker lands on the unit (/tmp), never on the card.
    marker = pathlib.Path("/tmp/clustermap_last_paths")
    assert marker.exists(), out
    txt = marker.read_text()
    assert "BACKUP_DIR=/tmp/clustermap_unit/backups" in txt
    assert "LOG_DIR=/tmp" in txt
    assert "WRITE_HOME=/tmp/clustermap_unit" in txt
    # Nothing was written under the card root.
    assert not pathlib.Path("/fs/sda0/last_install_paths.txt").exists()
    assert not pathlib.Path("/fs/sda0/backups").exists()


def test_no_card_mounted_still_works(car):
    """No card at all: /tmp still serves, because the card was never needed."""
    fn = "/sim/ewd_fn.sh"
    pathlib.Path(fn).write_text(_extract())
    p = car.run(["bash", "-c",
                 'CARD_ROOT=/fs/sda0; . /sim/ewd_fn.sh; ensure_write_dir 2>/dev/null; '
                 'echo "WRITE_HOME=$WRITE_HOME"; echo "ORIGINAL=$ORIGINAL"'],
                expect_rc=0)
    out = p.stdout
    assert "WRITE_HOME=/tmp/clustermap_unit" in out, out
    assert pathlib.Path("/tmp/clustermap_unit/backups").is_dir(), out
