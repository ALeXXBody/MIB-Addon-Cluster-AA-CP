"""qnxsh runner: the sim now EXECUTES QNX Neutrino sh errexit semantics.

Background: no installable shell (dash, bash, busybox ash, mksh, posh,
zsh — all probed empirically) reproduces the unit's behavior of exiting
the whole script when a command substitution fails inside a function
called from an `if` condition. That divergence is exactly how the v0.7.5
silent death (jsonlint-OK → `CLUSTERMAP_INSTALL_FAILED (code 1)` with
nothing between) stayed green in the sim while dying on the car.

qnxsh (tools/car_sim/qnxsh.py) closes it by source transformation: bare
single-command substitutions become `VAR=`cmd` || exit 127`, then the
script runs under plain sh. Guarded lines are byte-identical, so a qnxsh
run differs from a plain-sh run ONLY where the unit would have died.
"""
import pathlib
import shutil
import subprocess

import qnxsh
from conftest import APP_VIEWS, SYS_VIEWS

REPO = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo")
PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
CFG_KEY = "etc/eso/production/smartphone_integrator.json"


def _stage(car):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in APP_VIEWS:
        car.stage(v, "eso/lib/gal_dualscreen/gal_dualscreen.conf",
                  "GAL_PLAYER_WINDOW=1010x376\n"
                  "GAL_SECONDARY_DPI=125\n"
                  "GAL_SECONDARY_INSETS=40,40,127,127\n")
    return dst


def _probe_script():
    p = pathlib.Path("/sim/qnx_probe.sh")
    p.write_text("set -e\n"
                 "f() { x=`false`; echo inside-fn; }\n"
                 "if f; then echo cond-ok; fi\n"
                 "echo survived\n")
    return str(p)


def test_plain_sh_survives_where_qnx_dies(car):
    """Control: plain sh suppresses errexit in the condition-called
    function (rc=0, prints survived) — the sim's historical blind spot."""
    p = car.run(["sh", _probe_script()], expect_rc=0)
    assert "survived" in p.stdout, p.stdout


def test_qnxsh_reproduces_the_unit_silent_death(car):
    """The same probe through the qnxsh transformer dies rc=127 with no
    output — byte-for-byte the unit's v0.7.5 signature (rc=1, empty log
    tail). If this ever stops dying, the emulation itself is broken."""
    car.run(["sh", _probe_script()], expect_rc=0)  # control first
    import subprocess as _sp
    src = pathlib.Path("/sim/qnx_probe.sh").read_text()
    assert "|| exit" not in src
    qnxsh.transform_file("/sim/qnx_probe.sh")
    p = car.run(["sh", "/sim/qnx_probe.sh"], expect_rc=None)
    assert p.returncode == qnxsh.EXIT_CODE, \
        f"qnxsh did not reproduce the QNX death: rc={p.returncode}\n{p.stdout}\n{p.stderr}"
    assert "survived" not in p.stdout, p.stdout


def _stage_install(car):
    dst = _stage(car)
    (dst / "HOOK_ARMED").write_text("")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, CFG_KEY,
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')


def test_full_install_is_qnx_clean(car):
    """The whole first install under QNX semantics: must finish rc=0 and
    inject the hook. This is the run that v0.7.5 failed silently."""
    _stage_install(car)
    p = car.run_qnx(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "Hook environment installed" in out, out
    assert "libgal_hook.so" in pathlib.Path(SYS_VIEWS[0], CFG_KEY).read_text()


def test_repeat_install_skip_is_qnx_clean(car):
    """Repeat install under QNX semantics: the semantic skip, no ladder."""
    _stage_install(car)
    car.run_qnx(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    p = car.run_qnx(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "unchanged by this install; no system write needed" in out, out


def test_live_arm_under_total_refusal_is_qnx_clean(car):
    """Full app-refusal switch press under QNX semantics: the LIVE arm
    lands, persistence falls back to the card, verdict is DONE."""
    _stage(car)
    rt = pathlib.Path("/sim/rt")
    if rt.exists():
        shutil.rmtree(rt)
    rt.mkdir(parents=True)
    fail_all = "|".join(["", *APP_VIEWS, ""])
    p = car.run_qnx(["sh", f"{PKG}/greenmenu/gem/remote_on.sh"],
                    env={"GAL_RUNTIME_DIR": "/sim/rt",
                         "CB_MOUNT_FAIL": fail_all},
                    expect_rc=0)
    out = p.stdout + p.stderr
    assert (rt / "gal_remote").read_text() == "1\n", out
    assert "== DONE" in out, out
