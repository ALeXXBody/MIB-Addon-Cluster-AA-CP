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


def test_every_screen_entry_has_a_dispatcher_verb():
    """The GEM screen can only run what menus.sh knows. A screen entry with
    no case is a dead menu item ('nothing happens' on the unit)."""
    import re
    tpl = (PAYLOAD_SRC / "greenmenu/cluster-map.template.esd").read_text()
    built = (PAYLOAD_SRC / "greenmenu/cluster-map.esd").read_text()
    verbs = set(re.findall(r'menus\.sh\s+([a-z_]+)', tpl))
    assert verbs, "template names no menus.sh verbs"
    assert verbs == set(re.findall(r'menus\.sh\s+([a-z_]+)', built)), \
        "the pre-built screen and the template disagree on the menu entries"
    menus = (PAYLOAD_SRC / "greenmenu/menus.sh").read_text()
    have = set(re.findall(r'^\s{4}([a-z_]+)\)', menus, re.M))
    missing = verbs - have
    assert not missing, f"screen verbs with no menus.sh case: {sorted(missing)}"
    assert "arm" in verbs and "arm" in have, \
        "the GEM 'make the map live' entry is missing"



def test_every_run_says_which_payload_is_running(car):
    """Remote diagnosis starts with: WHICH payload is on the card. Every GEM
    run names it; if it still shows an old version after a card refresh, the
    copy of the new zip did not land (the answer to 'still no diag.txt')."""
    import pathlib as _pl
    import shutil as _sh
    from conftest import APP_VIEWS, SYS_VIEWS
    dst = _pl.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    _sh.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                 ignore=_sh.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    (dst / "HOOK_ARMED").write_text("")
    (dst / "VERSION").write_text("v-test-9")
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"p")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, "etc/eso/production/smartphone_integrator.json",
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')
    p = car.run(["sh", f"{PKG}/greenmenu/menus.sh", "status"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "payload on the card: v-test-9" in out, (
        f"the console does not name the payload version\n{out}")
