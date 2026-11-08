"""The GEM-side "make it live" action (menus.sh arm).

v0.4.21 ships the release zip ARMED (HOOK_ARMED is in mod/cluster_aa/), so the
owner's single "Run /mod/custom.sh" already makes the map live. This test
covers the other way in — the one the GEM offers when the card copy is
stage-only (owner deleted HOOK_ARMED): ClusterMap -> "2b. Make the map LIVE".
No card edit, no PC.

It also pins the ORDER of the one-click run: the GEM screen file is validated
and written FIRST, and only then may the hook go into gal's supervisor
config (that order is what keeps a bad screen from ever meeting a live hook).
"""
import pathlib
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

PAYLOAD_SRC = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")
PKG = "/fs/sda0/mod/cluster_aa"
CFG_KEY = "etc/eso/production/smartphone_integrator.json"


def _armed_anywhere():
    """The installer picks whichever system view is writable; the test must
    look where it actually wrote, not where we expected."""
    for v in SYS_VIEWS:
        f = pathlib.Path(v, CFG_KEY)
        if f.is_file() and "libgal_hook.so" in f.read_text():
            return True
    return False


def _stage(car, armed=False):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt",
                                                  "LICENSE"))
    if armed:
        (dst / "HOOK_ARMED").write_text("")
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    cfg = ('{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')
    for v in SYS_VIEWS:
        car.stage(v, CFG_KEY, cfg)
    return pathlib.Path(SYS_VIEWS[1], CFG_KEY)


def test_gem_arm_makes_a_staged_install_live(car):
    cfg = _stage(car, armed=False)
    # a stage-only install: nothing is live afterwards
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    assert not _armed_anywhere(), \
        f"an unarmed install armed the hook\n{p.stdout}"

    # the GEM entry: ClusterMap -> 2b. Make the map LIVE
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", "arm"], expect_rc=0)
    out = p.stdout + p.stderr
    assert _armed_anywhere(), \
        f"menus.sh arm did not arm the hook\n--out--\n{out}"
    # the stock player is preserved beside the live one (Rule 1 undo)
    assert any(pathlib.Path(v,
                            "navigation/stream-player.aacluster-original").exists()
               for v in APP_VIEWS), "stock player was not preserved"
    # and the console stays short
    n = len([l for l in out.splitlines() if l.strip()])
    assert n < 25, f"arm console is too verbose ({n} lines)\n{out}"


def test_gem_arm_is_idempotent(car):
    cfg = _stage(car, armed=False)
    car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    car.run(["sh", f"{PKG}/greenmenu/menus.sh", "arm"], expect_rc=0)
    first = {v: (pathlib.Path(v, CFG_KEY).read_text()
                 if pathlib.Path(v, CFG_KEY).is_file() else "")
             for v in SYS_VIEWS}
    car.run(["sh", f"{PKG}/greenmenu/menus.sh", "arm"], expect_rc=0)
    second = {v: (pathlib.Path(v, CFG_KEY).read_text()
                  if pathlib.Path(v, CFG_KEY).is_file() else "")
              for v in SYS_VIEWS}
    assert second == first, \
        "a second arm changed the supervisor config (must be idempotent)"


def test_every_screen_entry_is_a_bare_existing_path(car):
    """M.I.B.'s own screens never put arguments inside a screen's script
    value - the GEM resolves the WHOLE quoted string as the script name
    ("menus.sh status" therefore cannot exist). The contract: every entry
    is @GREENMENU@<relative-path>, that file exists in the payload, and
    nothing in the value needs parsing beyond the path itself."""
    import re
    tpl = (PAYLOAD_SRC / "greenmenu/cluster-map.template.esd").read_text()
    built = (PAYLOAD_SRC / "greenmenu/cluster-map.esd").read_text()
    tpl_paths = re.findall(r'"@GREENMENU@([^"]+)"', tpl)
    assert tpl_paths, "template names no script entries"
    greenmenu = PAYLOAD_SRC / "greenmenu"
    for rel in tpl_paths:
        target = greenmenu / rel
        assert target.is_file(), f"screen names a missing file: {rel}"
        assert " " not in rel, f"an entry still carries an argument: {rel}"
    built_paths = re.findall(r'"/net/mmx/fs/sda0/mod/cluster_aa/([^"]+)"', built)
    assert built_paths, "built screen names no script entries"
    for rel in built_paths:
        assert " " not in rel, f"an entry still carries an argument: {rel}"
        assert (PAYLOAD_SRC / rel).is_file(), (
            f"built screen names a missing file: {rel}")
    assert "gem/arm.sh" in built, "the GEM 'make the map LIVE' entry is gone"


def test_every_gem_wrapper_calls_the_dispatcher_with_a_known_verb():
    """The wrappers keep ONE dispatcher (menus.sh) so a partial card copy
    cannot produce dead switches - each wrapper is one verb, no args."""
    import re
    gem = (PAYLOAD_SRC / "greenmenu/gem")
    menus = (PAYLOAD_SRC / "greenmenu/menus.sh").read_text()
    have = set(re.findall(r'^\s{4}([a-z_]+)\)', menus, re.M))
    for w in sorted(gem.glob("*.sh")):
        body = w.read_text()
        m = re.search(r'exec sh "\$HERE/\.\./menus\.sh" ([a-z_]+)', body)
        assert m, f"wrapper {w.name} does not call the dispatcher"
        verb = m.group(1)
        assert verb in have, f"wrapper {w.name} -> verb '{verb}' with no case"
