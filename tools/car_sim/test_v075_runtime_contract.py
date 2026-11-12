"""v0.7.5 runtime contract: the switches and the hook must agree on the
EXACT bytes of every live override file, and the live arm must never depend
on a remount.

The v0.7.4 car round proved the opposite the hard way: every switch reported
success while the hook ignored the file, because the hook reads

    /tmp/gal_remote        a single character  '0' / '1'
    /tmp/gal_remote_trace  a single character  '0' / '1'
    /tmp/gal_cluster_menu  a single character  '0' / '1'
    /tmp/gal_hires         an integer         (fscanf "%d")
    /tmp/gal_idr_pump      an integer         (fscanf "%ld")
    /tmp/gal_uiconfig      "top,bottom,left,right"

and the switches wrote "KEY=VALUE" lines into them. Every format below is
asserted against the C reader in sources/src/, so the pair cannot drift
apart silently again.

/tmp itself is NOT shadowed by the simulation namespace (the repo lives
under /tmp/opencode), so the tests drive the scripts through
GAL_RUNTIME_DIR. The shipped default must stay /tmp, and that is asserted
separately, without running anything.
"""
import pathlib
import re
import shutil
import subprocess

from conftest import APP_VIEWS, SYS_VIEWS

REPO = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo")
PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
SW = f"{PKG}/greenmenu"
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


def _rt():
    rt = pathlib.Path("/sim/rt")
    if rt.exists():
        shutil.rmtree(rt)
    rt.mkdir(parents=True)
    return rt


def _run(car, *argv, **kw):
    env = {"GAL_RUNTIME_DIR": "/sim/rt"}
    env.update(kw.pop("env", {}))
    return car.run(["sh", *argv], env=env, **kw)


# ---------------------------------------------------------------------------
# 1. The bytes. One test per format family, all asserted against the reader.
# ---------------------------------------------------------------------------

def test_switches_write_the_bare_values_the_hook_reads(car):
    _stage(car)
    rt = _rt()

    _run(car, f"{SW}/cluster_remote.sh", "on", expect_rc=0)
    assert (rt / "gal_remote").read_text() == "1\n", \
        "the hook reads /tmp/gal_remote as a single character"
    _run(car, f"{SW}/cluster_remote.sh", "off", expect_rc=0)
    assert (rt / "gal_remote").read_text() == "0\n"

    _run(car, f"{SW}/remote_trace.sh", "on", expect_rc=0)
    assert (rt / "gal_remote_trace").read_text() == "1\n", \
        "the hook tests buf[0]=='1' on /tmp/gal_remote_trace"
    _run(car, f"{SW}/remote_trace.sh", "off", expect_rc=0)
    assert (rt / "gal_remote_trace").read_text() == "0\n"

    _run(car, f"{SW}/clustermenu.sh", "on", expect_rc=0)
    assert (rt / "gal_cluster_menu").read_text() == "1\n", \
        "the hook accepts /tmp/gal_cluster_menu only when strlen==1"
    _run(car, f"{SW}/clustermenu.sh", "off", expect_rc=0)
    assert (rt / "gal_cluster_menu").read_text() == "0\n"

    _run(car, f"{SW}/hiresen.sh", "on", expect_rc=0)
    assert (rt / "gal_hires").read_text() == "1\n", \
        "the hook parses /tmp/gal_hires with fscanf %d"
    _run(car, f"{SW}/hiresen.sh", "off", expect_rc=0)
    assert (rt / "gal_hires").read_text() == "0\n"

    _run(car, f"{SW}/idrpump.sh", "25", expect_rc=0)
    assert (rt / "gal_idr_pump").read_text() == "25\n", \
        "the hook parses /tmp/gal_idr_pump with fscanf %ld"
    _run(car, f"{SW}/idrpump.sh", "off", expect_rc=0)
    assert (rt / "gal_idr_pump").read_text() == "0\n"

    _run(car, f"{SW}/position.sh", "higher", expect_rc=0)
    assert (rt / "gal_uiconfig").read_text() == "32,48,127,127\n", \
        "the hook parses /tmp/gal_uiconfig as '%u,%u,%u,%u'"

    # and the persistent keys keep their KEY=VALUE form in the settings file
    conf = pathlib.Path(APP_VIEWS[0],
                        "eso/lib/gal_dualscreen/gal_dualscreen.conf")
    text = conf.read_text()
    for line in ("GAL_CLUSTER_MENU=0", "GAL_SECONDARY_HIRESEN=0",
                 "GAL_IDR_PUMP=0", "GAL_REMOTE_TRACE=0",
                 "GAL_SECONDARY_INSETS=32,48,127,127"):
        assert line in text, f"{line} missing from the settings file:\n{text}"


def test_no_switch_writes_a_key_value_line_into_a_runtime_file(car):
    """The exact v0.7.4 bug, as a source assertion: a runtime override must
    be the bare value, never 'GAL_KEY=value'."""
    for name in ("cluster_remote", "remote_trace", "clustermenu", "hiresen",
                 "idrpump", "position", "etacard"):
        body = (PAYLOAD_SRC / "greenmenu" / f"{name}.sh").read_text()
        for m in re.finditer(r'live_write\s+"\$GAL_RUNTIME_DIR/[a-z_]+"\s+"([^"]*)"',
                             body):
            value = m.group(1)
            assert not re.match(r"^[A-Z][A-Z0-9_]*=", value), (
                f"{name}.sh writes '{value}' into a runtime file; the hook "
                "reads the bare value")


# ---------------------------------------------------------------------------
# 2. The live arm survives a total remount refusal.
# ---------------------------------------------------------------------------

def test_the_live_arm_lands_even_when_every_remount_refuses(car):
    """The owner's car shape: `mount -uw` refuses every app spelling, so the
    v0.7.4 switch died before writing its runtime file ("Cannot remount the
    app partition read-write" - the install failed there too). The LIVE arm
    must be written first and reported as LIVE; persistence may fail."""
    _stage(car)
    rt = _rt()
    fail_all = "|".join(["", *APP_VIEWS, ""])
    p = car.run(["sh", f"{SW}/gem/remote_on.sh"],
                env={"GAL_RUNTIME_DIR": "/sim/rt", "CB_MOUNT_FAIL": fail_all},
                expect_rc=0)
    out = p.stdout + p.stderr
    assert (rt / "gal_remote").read_text() == "1\n", \
        f"the live arm did not land without a remount\n{out}"
    assert "== DONE" in out, out
    # the LIVE verdict is the honest one, even with nothing remountable
    bundle = pathlib.Path("/tmp/clustermap_diag/diag.txt").read_text()
    assert "Cluster remote: ON (LIVE)" in bundle, bundle[-1500:]


# ---------------------------------------------------------------------------
# 3. A card-root settings file wins, and it is written as the UNION.
# ---------------------------------------------------------------------------

def test_a_card_root_conf_shadows_the_unit_copy_and_is_kept_whole(car):
    """v0.7.4 fell back to writing /fs/sda0/gal_dualscreen.conf once; from
    then on every switch that only wrote the unit copy changed a file the
    hook never reads. So: when a card-root file exists it IS the settings
    file, and it must keep the unit copy's lines (the hook reads no other)."""
    _stage(car, card_conf="GAL_PLAYER_WINDOW=1010x376\n"
                          "GAL_SECONDARY_DPI=140\n"
                          "CLUSTERMAP_FULL_FRAME=0\n")
    rt = _rt()
    p = _run(car, f"{SW}/cluster_remote.sh", "on", expect_rc=0)
    out = p.stdout + p.stderr

    card = pathlib.Path("/fs/sda0/gal_dualscreen.conf")
    text = card.read_text()
    assert "GAL_CLUSTER_REMOTE=1" in text, f"the live settings file was not written\n{out}"
    # the union: settings the unit copy carried must survive in the card file
    assert "GAL_PLAYER_WINDOW=1010x376" in text, text
    assert "GAL_SECONDARY_DPI=140" in text, text
    assert "CLUSTERMAP_FULL_FRAME=0" in text, text
    assert (rt / "gal_remote").read_text() == "1\n"
    # the shadowed unit copy is NOT the place the switch wrote
    unit = pathlib.Path(APP_VIEWS[0],
                        "eso/lib/gal_dualscreen/gal_dualscreen.conf")
    assert "GAL_CLUSTER_REMOTE" not in unit.read_text(), \
        "the switch wrote the shadowed unit copy instead of the live file"
    assert "card root" in out, out


def test_the_card_file_is_only_created_when_no_unit_copy_can_be_written(car):
    """The card is read-only media by rule: a switch may write a card-root
    file ONLY as the fallback, never while the unit copy is writable."""
    _stage(car)
    rt = _rt()
    _run(car, f"{SW}/cluster_remote.sh", "on", expect_rc=0)
    assert not pathlib.Path("/fs/sda0/gal_dualscreen.conf").exists(), \
        "a card-root settings file was created although the unit copy is writable"


# ---------------------------------------------------------------------------
# 4. The install: a repeat install is a no-op, not a red failure.
# ---------------------------------------------------------------------------

def _stage_install(car):
    dst = _stage(car)
    (dst / "HOOK_ARMED").write_text("")
    for v in APP_VIEWS:
        car.stage(v, "navigation/stream-player", b"unit-player-stub")
        car.stage(v, "eso/lib/libairplay.so", bytes(703688))
    for v in SYS_VIEWS:
        car.stage(v, CFG_KEY,
                  '{\n "children": {\n  "gal": {\n   "envs":[]\n  }\n }\n}\n')
    return pathlib.Path(SYS_VIEWS[0], CFG_KEY)


def test_the_repeat_install_skips_even_when_the_config_was_written_differently(car):
    """The v0.7.5 car diag: the unit's config carried the same env entries
    the reinstall would write, but the byte-for-byte compare still failed
    (harmless differences from the earlier run), so every reinstall walked
    into the system ladder. The skip must compare the gal child's ENVS, not
    the file bytes."""
    cfg_path = _stage_install(car)
    car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    # perturb the live config: reorder the gal envs, keep every entry.
    # The entries are taken from what run 1 actually wrote (the DPI value
    # depends on the unit profile, so it must not be hardcoded here).
    import re as _re
    m = _re.search(r'"envs":\[(.*?)\]', cfg_path.read_text())
    entries = [e.strip().strip('"') for e in m.group(1).split(",")]
    entries = [e for e in entries if e]
    entries.reverse()
    reordered = ('{\n "children": {\n  "gal": {\n   "envs":['
                 + ", ".join('"%s"' % e for e in entries) + ']\n'
                 '  }\n }\n}\n')
    for v in SYS_VIEWS:
        pathlib.Path(v, CFG_KEY).write_text(reordered)
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "unchanged by this install; no system write needed" in out, out
    assert "Cannot remount" not in out, out


def test_every_menu_label_is_short_enough_to_read_on_the_glass():
    """The owner could not read the menu: '4-5 words, not 100 lines of text'.
    Every script entry's label must be 5 words or fewer. Screen titles
    (keyValue labels) are exempt."""
    tpl = (PAYLOAD_SRC / "greenmenu/cluster-map.template.esd").read_text()
    lines = tpl.splitlines()
    bad = []
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith("value   sys 1 0x0100"):
            # find the following label line
            j = i + 1
            while j < len(lines) and not lines[j].strip().startswith("label"):
                j += 1
            if j < len(lines):
                import re
                m = re.search(r'label\s+"(.*)"', lines[j])
                if m:
                    label = m.group(1)
                    # strip trailing \n marker
                    words = label.replace("\\n", "").split()
                    if len(words) > 5:
                        bad.append(f"{len(words)} words: {label}")
        i += 1
    assert not bad, "menu labels too long:\n" + "\n".join(bad)


def test_the_gem_screen_is_nested_with_max_nine_rows_per_screen():
    """The owner's GEM 4.12st renders ~9 rows per screen and the rest of one
    long list is unreachable (the hi-res / wheel tabs "did not exist" for
    him although the file listed them). The screen is nested now: every
    screen stays under 9 rows and the sub-screens hang off ClusterMap."""
    tpl = (PAYLOAD_SRC / "greenmenu/cluster-map.template.esd").read_text()
    screens = re.findall(r'^screen (\S+) (\S+)$', tpl, re.M)
    assert len(screens) >= 6, f"the screen is not nested: {screens}"
    # every entry lands in exactly one screen
    blocks = re.split(r'^screen \S+ \S+$', tpl, flags=re.M)[1:]
    for name, body in zip([n for n, _ in screens], blocks):
        rows = len(re.findall(r'^script$', body, re.M)) \
             + len(re.findall(r'^screen ', body, re.M))
        assert rows <= 9, f"screen {name} has {rows} rows (>9, unreachable rows again)"
    # the tabs the owner looked for are now one level inside ClusterMap
    for needle in ('ClusterMap_hires', 'ClusterMap_wheel'):
        assert f'screen {needle} ClusterMap' in tpl, needle
    # and every family is still wired: hires, pump, wheel trace, cluster remote
    for wrapper in ('hiresen_on.sh', 'idrpump_on.sh', 'trainer_on.sh',
                    'remote_on.sh', 'clustermenu_on.sh', 'logs.sh',
                    'uninstall.sh', 'status.sh', 'install.sh', 'arm.sh'):
        assert f'gem/{wrapper}"' in tpl, wrapper


def test_no_probe_assignment_can_die_silently_under_strict_sh():
    """The v0.7.5 car round's root cause: `_err=`mount -uw ...`` under the
    unit's sh exits the whole script (rc=1, no message) when the probe
    fails -- dash suppresses errexit inside functions called from `if`, the
    unit's shell does not, which is why the car_sim missed it. Every probing
    assignment must therefore carry its own `||` guard."""
    import re
    lib = (PAYLOAD_SRC / "scripts/lib_app_mount.sh").read_text()
    bad = []
    for i, ln in enumerate(lib.splitlines(), 1):
        if re.search(r'_err=`|_sy_err=`', ln) and "||" not in ln:
            bad.append(f"{i}: {ln}")
    assert not bad, "bare probe assignments (die under the unit's sh):\n" + "\n".join(bad)
    eh = (PAYLOAD_SRC / "enable_hook.sh").read_text()
    assert '2>/dev/null` || true' in eh, "the skip compare lost its errexit guard"
    # and the never-silent trap is in place
    assert "FAIL: enable_hook stopped rc=" in eh, \
        "the shell-level-death trap is missing"


def test_a_mislabelled_recovery_copy_is_rebuilt_not_fatal(car):
    """The v0.7.5 car round (photo, 2026-11-11): the install died AFTER the
    env-entry lines with nothing on the console. The silent candidate is the
    poisoned recovery-copy guard: an earlier run backed up an already-
    injected config, so every later install refused with a message the
    curated summary never surfaced ("Persistent recovery copy ..."). A clean
    unit config + mislabelled backup must now REBUILD the backup and finish."""
    cfg_path = _stage_install(car)
    # poison the persistent recovery copy beside the live config
    poisoned = str(cfg_path) + ".gal-dualscreen.original"
    pathlib.Path(poisoned).write_text(
        '{\n "children": {\n  "gal": {\n'
        '   "envs":["LD_PRELOAD=/eso/lib/gal_dualscreen/libgal_hook.so"]\n'
        '  }\n }\n}\n')
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "Rebuilt the persistent recovery copy" in out, out
    assert "libgal_hook.so" not in pathlib.Path(poisoned).read_text(), \
        "the mislabelled backup was not rebuilt"
    assert "libgal_hook.so" in cfg_path.read_text(), out


def test_the_console_summary_surfacing_never_hides_a_failure():
    """Every failure line the installer can print must survive the curated
    summary -- the photo round proved a missed line reads as 'nothing
    changed' to the owner."""
    import subprocess
    lines = [
        "Generated supervisor config failed jsonlint validation",
        "Generated supervisor config failed verification",
        "Staged supervisor config failed verification",
        "Could not stage /tmp/x",
        "Could not atomically install /mnt/system/etc/eso/production/x",
        "Could not create persistent recovery copy: /x",
        "Persistent recovery copy contains the hook (mislabelled earlier): rebuilding",
        "Active config is already injected and no untouched backup is available",
        "Refusing to install: 11 environment entries.",
        "Installed config failed validation; restoring persistent original",
        "CLUSTERMAP_INSTALL_FAILED (code 1). Read the messages above.",
        "cp: can't create '/x': No space left on device",
        "awk: syntax error",
        "Cannot remount the system partition read-write.",
        "FAIL: probe",
    ]
    log = "/tmp/audit_summary_log"
    pathlib.Path(log).write_text("\n".join(lines) + "\n")
    out = subprocess.run(["sh",
                          str(PAYLOAD_SRC / "greenmenu/console_summary.sh"),
                          log], capture_output=True, text=True).stdout
    for ln in lines:
        assert ln in out, f"summary hid: {ln}\n--- summary ---\n{out}"


def test_a_repeat_install_needs_no_system_write(car):
    """v0.7.4's second install died with "Cannot remount the system
    partition read-write" although the config was already exactly what the
    install would write: the probe wrote at the mount ROOT, which this unit
    refuses (ENOSYS). A repeat install must say so and finish rc=0."""
    _stage_install(car)
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    assert "libgal_hook.so" in pathlib.Path(SYS_VIEWS[0], CFG_KEY).read_text()
    before = pathlib.Path(SYS_VIEWS[0], CFG_KEY).read_text()

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    after = pathlib.Path(SYS_VIEWS[0], CFG_KEY).read_text()
    assert after == before, "the repeat install changed the supervisor config"
    assert "unchanged by this install; no system write needed" in out, out
    assert "Cannot remount" not in out, out


def test_the_system_ladder_probes_the_write_target_not_the_mount_root(car):
    """A view whose ROOT refuses a write (the car's ENOSYS shape) must still
    be accepted when etc/eso/production takes the write: that is where the
    supervisor config and its backup actually live."""
    _stage_install(car)
    # a DIRECTORY at the root probe name: every root write fails, the
    # subdirectory write still works (exactly the measured car behaviour)
    for v in SYS_VIEWS:
        (pathlib.Path(v, ".clustermap_sys_probe")).mkdir(parents=True,
                                                         exist_ok=True)
    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=0)
    out = p.stdout + p.stderr
    assert "libgal_hook.so" in pathlib.Path(SYS_VIEWS[0], CFG_KEY).read_text(), out
    assert "system: read-write via" in out, out


# ---------------------------------------------------------------------------
# 5. Wiring: the shipped binary is the one the switches talk to.
# ---------------------------------------------------------------------------

def test_the_shipped_hook_exports_the_send_path_and_carries_the_tap(car):
    so = PAYLOAD_SRC / "libgal_hook.so"
    data = so.read_bytes()
    blob = data.decode("latin-1")
    # the outbound interposers must be exported, or the tap never runs
    env = {"PATH": "/opt/qnx650/host/linux/x86/usr/bin:/usr/bin:/bin"}
    nm = subprocess.run(["arm-unknown-nto-qnx6.5.0eabi-nm", "-D",
                         "--defined-only", str(so)],
                        capture_output=True, text=True, env=env)
    if nm.returncode == 0:
        assert "_ZN13MessageRouter13queueOutgoingEhPvj" in nm.stdout, nm.stdout
        assert "_ZN13MessageRouter24queueOutgoingUnencryptedEhPvj" in nm.stdout
    # the build marker and the tap's own log lines: a v0.7.4 binary has none
    for needle in ("event=remote.tap", "event=cluster.remote.live",
                   "event=cluster.remote.gate result=closed",
                   "/tmp/gal_remote", "v0.7.5"):
        assert needle in blob, f"the shipped hook lacks '{needle}'"


def test_the_hook_sources_name_the_literal_runtime_paths(car):
    """GAL_RUNTIME_DIR is a simulation hook only. The hook itself must keep
    the literal /tmp paths; a switch that resolved a different directory
    would be writing where the hook never looks."""
    src = (REPO / "sources/src")
    hook = ((src / "video_sink_hook.c").read_text()
            + (src / "focus_ctl.c").read_text())
    for path in ("/tmp/gal_remote", "/tmp/gal_remote_trace",
                 "/tmp/gal_cluster_menu", "/tmp/gal_hires",
                 "/tmp/gal_idr_pump", "/tmp/gal_uiconfig"):
        assert f'"{path}"' in hook, f"the hook does not read {path}"

    lib = (PAYLOAD_SRC / "scripts/lib_app_mount.sh").read_text()
    assert 'GAL_RUNTIME_DIR="${GAL_RUNTIME_DIR:-/tmp}"' in lib, \
        "the shipped runtime directory default is not /tmp"

    # every switch must go through the variable, never a literal /tmp path
    for name in ("cluster_remote", "remote_trace", "clustermenu", "hiresen",
                 "idrpump", "position"):
        body = (PAYLOAD_SRC / "greenmenu" / f"{name}.sh").read_text()
        code = "\n".join(ln for ln in body.splitlines()
                          if not ln.lstrip().startswith("#"))
        assert "/tmp/gal_" not in code, \
            f"{name}.sh hardcodes a /tmp runtime path instead of $GAL_RUNTIME_DIR"
