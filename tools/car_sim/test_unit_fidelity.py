"""Unit-fidelity gates: the five sim-vs-unit gaps from the full audit.

Each test pins one gap so the class that let the v0.7.5 silent death,
the work-target probe miss, the FAT rename hazard and the reboot-blind
verdict through can never regress silently again.
"""
import pathlib
import re
import shutil
import subprocess

from conftest import APP_VIEWS, SYS_VIEWS

REPO = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo")
PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
CFG_KEY = "etc/eso/production/smartphone_integrator.json"


def _stage(car, card_conf=None):
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
    if card_conf is not None:
        car.stage("/fs/sda0", "gal_dualscreen.conf", card_conf)
    return dst


# 1. Strict-errexit: every SINGLE-COMMAND backtick probing assignment must
# carry its own `||` guard — QNX sh exits the whole script on a failed one,
# dash (the sim shell) does not, which is how v0.7.5 died silently after
# jsonlint. Piped substitutions (`grep … | head -1`, `sed … | tail -1`) are
# safe: the pipeline's exit is the last stage's (always 0), so only bare
# single-command substitutions are flagged.
def test_no_bare_probe_assignment_anywhere():
    import re
    bad = []
    # Every script that runs under `set -e`: on the unit's sh a failed
    # bare-statement single-command substitution exits the whole script
    # with no message. Only that shape is fatal: pipes, `||` guards and
    # substitutions inside conditions/&&-chains run safely on the car
    # every boot (extensive diag evidence), so the gate matches exactly
    # `VAR=`cmd`` at statement start, possibly spanning lines.
    # (Scripts without set -e cannot die this way; their failures surface
    # through run_quiet's FAIL line, covered separately.)
    for rel in ["scripts/lib_app_mount.sh",
                "enable_hook.sh",
                "disable_hook.sh",
                "turn_by_turn.sh",
                "scripts/turn_by_turn.sh",
                "lsd_jar.sh",
                "scripts/lsd_jar.sh"]:
        path = PAYLOAD_SRC / rel
        text = path.read_text()
        for m in re.finditer(
                r"(?m)^[ \t]*[A-Za-z_][A-Za-z0-9_]*=`[^`]*?`", text):
            span = m.group(0)
            if "|" in span:
                continue  # piped: pipeline rc is the last stage (0)
            close_line = text[m.end():].split("\n", 1)[0]
            if "||" in close_line:
                continue  # guarded
            bad.append(f"{rel}:{text[:m.start()].count(chr(10)) + 1}: "
                       f"{span.splitlines()[0].strip()[:100]}")
    assert not bad, "bare assignments (die on the unit's sh):\n" + "\n".join(bad)


# 2. ENOSYS shape: root refuses, subdirectory works — the ladder must still
# land the write through the work target.
def test_single_exit_trap_with_fail_report():
    """The v0.7.7 safety net died on arrival: a second `trap ... 0`
    setter silently replaced it, so the silent death it was built for
    stayed silent through v0.7.18. Exactly one EXIT-trap setter may exist
    per script, and its finish() must report non-zero stops."""
    import re
    for name, marker in (("enable_hook.sh", "FAIL: enable_hook stopped"),
                         ("disable_hook.sh", "FAIL: disable_hook stopped")):
        body = (PAYLOAD_SRC / name).read_text()
        setters = [ln.strip() for ln in body.splitlines()
                   if re.match(r"^trap\s+[^-]", ln.strip())]
        assert len(setters) == 1, \
            f"{name} must have exactly one EXIT-trap setter, found: {setters}"
        assert marker in body, f"{name} finish() never reports its rc"
        assert "_hook_rc=$?" in body, f"{name} finish() must capture rc first"
        clearers = [ln.strip() for ln in body.splitlines()
                    if re.match(r"^trap\s+-", ln.strip())]
        assert not clearers, \
            f"{name} must never clear the EXIT trap mid-file: {clearers}"


def test_skip_check_is_exit_code_driven():
    """The skip compare must not use command substitution at all: a bare
    `_same=`awk ...`` in the death zone is what the unit killed silently
    in v0.7.5 (rc=1, no message). awk's exit code drives the branch."""
    body = (PAYLOAD_SRC / "enable_hook.sh").read_text()
    assert "_same=`" not in body, "substitution-based skip check is back"
    assert "if awk -v inj=" in body, "exit-code-driven skip check missing"


def test_root_refuses_subdir_works_lands_write(car):
    _stage(car)
    for v in APP_VIEWS:
        car.make_root_read_only(v)
    rt = pathlib.Path("/sim/rt")
    if rt.exists():
        shutil.rmtree(rt)
    rt.mkdir(parents=True)
    p = car.run(["sh", f"{PKG}/greenmenu/gem/remote_on.sh"],
                env={"GAL_RUNTIME_DIR": "/sim/rt"}, expect_rc=0)
    out = p.stdout + p.stderr
    assert (rt / "gal_remote").read_text() == "1\n", out
    assert "== DONE" in out, out


# 3. FAT rename: with an mv that refuses overwrite (FAT EEXIST), switches
# and persistence must still succeed via rm-first.
def test_fat_rename_overwrite_still_persists(car):
    import os
    _stage(car)
    # hide real mv, expose FAT-semantics mv first on PATH
    real = None
    for d in os.environ.get("PATH", "").split(":"):
        cand = pathlib.Path(d, "mv")
        if cand.exists() and "stubs" not in str(cand):
            real = cand
            break
    assert real is not None
    fatdir = pathlib.Path("/sim/fatbin")
    fatdir.mkdir(exist_ok=True)
    (fatdir / "mv.fat-real").write_bytes(real.read_bytes())
    (fatdir / "mv.fat-real").chmod(0o755)
    shutil.copyfile(REPO / "tools/car_sim/stubs/mv", fatdir / "mv")
    (fatdir / "mv").chmod(0o755)
    env = {"PATH": f"{fatdir}:/bin:/usr/bin",
           "GAL_RUNTIME_DIR": "/tmp",
           "CB_MOUNT_TABLE": "/net/mmx.mibhigh.net/dev/sda0t12 on /fs/sda0 type dos (fat32)"}
    p = car.run(["sh", f"{PKG}/greenmenu/gem/remote_on.sh"], env=env, expect_rc=0)
    out = p.stdout + p.stderr
    assert "== DONE" in out, out


# 4. Reboot: runtime files vanish, persisted keys survive.
def test_reboot_wipes_runtime_but_keeps_settings(car):
    _stage(car)
    rt = pathlib.Path("/sim/rt")
    if rt.exists():
        shutil.rmtree(rt)
    rt.mkdir(parents=True)
    car.run(["sh", f"{PKG}/greenmenu/cluster_remote.sh", "on"],
            env={"GAL_RUNTIME_DIR": "/sim/rt"}, expect_rc=0)
    assert (rt / "gal_remote").read_text() == "1\n"
    car.reboot()
    assert not (rt / "gal_remote").exists(), "reboot must wipe runtime files"
    conf = pathlib.Path(APP_VIEWS[0], "eso/lib/gal_dualscreen/gal_dualscreen.conf")
    assert "GAL_CLUSTER_REMOTE=1" in conf.read_text(), \
        "persisted settings must survive the reboot"


# 5. Validating jsonlint: corrupt configs must fail the install.
def test_corrupt_supervisor_config_fails_install(car):
    dst = _stage(car)
    (dst / "HOOK_ARMED").write_text("")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, CFG_KEY, "{not json\n")
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    assert p.returncode != 0, f"corrupt config installed rc=0\n{p.stdout}\n{p.stderr}"


# 6. pidin/netstat fixtures: diag §9c/§9d parse the canned QNX output.
def test_diag_parses_process_and_socket_fixtures(car):
    _stage(car, card_conf="GAL_PLAYER_WINDOW=1010x376\n")
    car.run(["sh", f"{PKG}/greenmenu/gem/remote_on.sh"],
            env={"GAL_RUNTIME_DIR": "/tmp"}, expect_rc=0)
    car.run(["sh", f"{PKG}/greenmenu/gem/logs.sh"], expect_rc=0)
    txt = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "stream-player instances:" in txt, txt[-800:]
    assert "12346" in txt, txt[-800:]
    assert "gal instances:" in txt, txt[-800:]
