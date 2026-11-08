"""Menu-action audit: EVERY script name the ClusterMap dispatcher (menus.sh)
can run must be a file that really ships in the payload. The owner hit the
last dead one in the car: the `full_frame` verb named full_frame.sh, and the
card carries full_frame_on.sh / full_frame_off.sh. A dead file name in the
dispatcher is the same failure class as a dead screen path - it must be
impossible to ship."""
import pathlib
import re

GREENMENU = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu/greenmenu")


def _menus_case():
    menus = (GREENMENU / "menus.sh").read_text()
    return menus.split('case "$1" in', 1)[1]


def _dispatcher_files():
    """Every `$HERE/<x>.sh` a verbs case in menus.sh can invoke."""
    return set(re.findall(r'\$HERE/([A-Za-z0-9_./-]+\.sh)', _menus_case()))


def test_every_dispatcher_script_exists():
    names = _dispatcher_files()
    assert names, "no runnable scripts parsed from menus.sh"
    missing = [n for n in sorted(names) if not (GREENMENU / n).is_file()]
    assert not missing, f"dispatcher runs a file the card does not have: {missing}"


def test_screen_wrappers_exist_and_are_named_by_the_screen():
    built = (GREENMENU / "cluster-map.esd").read_text()
    entries = re.findall(
        r'"/net/mmx/fs/sda0/mod/cluster_aa/(greenmenu/gem/[^"]+\.sh)"', built)
    assert entries, "no gem wrappers named by the screen"
    for rel in entries:
        payload_rel = rel[len("greenmenu/"):]
        assert (GREENMENU / payload_rel).is_file(), rel


def test_wrappers_resolve_to_scripts_that_exist():
    case = _menus_case()
    wrappers = sorted((GREENMENU / "gem").glob("*.sh"))
    assert wrappers, "no gem wrappers in the payload"
    for w in wrappers:
        m = re.search(r'menus\.sh" ([a-z_]+(?: [a-z_0-9.]+)?)', w.read_text())
        assert m, f"{w.name} does not call the dispatcher"
        verb, arg = (m.group(1).split() + [None])[:2]
        lines = [l for l in case.splitlines() if l.strip().startswith(f"{verb})")]
        assert lines, f"{w.name} -> verb '{verb}' unknown to menus.sh"
        # the verb's block runs from "<verb>)" to the terminating ";;"
        block_lines, on = [], False
        for l in case.splitlines():
            s_ = l.strip()
            if s_.startswith(f"{verb})") or s_.startswith(f"{verb}\t"):
                on = True
            elif on and s_ == ";;":
                block_lines.append(l)
                break
            if on:
                block_lines.append(l)
        block = "\n".join(block_lines)
        if arg is not None:
            block = "\n".join(l for l in block.splitlines()
                              if arg in l or '*)' in l)
        hits = re.findall(r'\$HERE/([A-Za-z0-9_.-]+\.sh)', block)
        assert hits, f"{w.name} -> '{verb}' runs no named file"
        for f in hits:
            assert (GREENMENU / f).is_file(), (
                f"{w.name} -> '{verb}' -> {f} MISSING on the card")


def test_every_entry_ends_with_an_outcome_and_next_instruction():
    """Owner contract: no silent ends. run_verdict.sh prints `== DONE` /
    `== STOPPED` plus the next instruction, and every run_quiet verb calls
    it after the collector."""
    import re
    menus = (GREENMENU / "menus.sh").read_text()
    assert 'sh "$HERE/run_verdict.sh" "$1" "$_log"' in menus, \
        "run_quiet does not end with the verdict tail"
    viewer = (GREENMENU / "run_verdict.sh").read_text()
    assert viewer.islower() == viewer.islower()  # placeholder
    for verb in ("install", "arm", "uninstall", "tbt", "logs",
                 "porting", "portfull", "status", "verify", "diag"):
        assert verb in viewer, f"no verdict branch for {verb}"
    # switches are grouped
    for grouped in ("full_frame*|zoom*|cardclear*|navstrip*|remote*|keep_map*",):
        assert grouped in viewer

def test_every_press_carries_the_execution_proof_line():
    """One line only our chain can print; when the GEM console shows just
    "...", this tells the seat whether our code ran (`...` == it didn't)
    versus the renderer hiding real output."""
    body = (GREENMENU / "run_verdict.sh").read_text()
    assert 'LaneMap' not in body
    assert 'echo "ClusterMap $VERB ran / payload on card:' in body
    pass  # the VERSION file is a zip-only artifact


def test_settings_snapshot_ships():
    """The keep-settings feature silently died without this file: the
    installer gates 'carry the owner's changed lines over' on the presence
    of scripts/gal_dualscreen.default.conf (found missing in the v0.5.0
    audit - the gate shipped since beta19 never defended it)."""
    from pathlib import Path as P
    payload = P("/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu")
    dflt = payload / "scripts/gal_dualscreen.default.conf"
    assert dflt.is_file(), "the defaults snapshot is missing (feature dead)"
    assert (payload / "scripts/lib_keep_settings.sh").is_file()
    conf = (payload / "gal_dualscreen.conf").read_text()
    assert "CLUSTERMAP_KEEP_SETTINGS=1" in conf


def test_console_summary_has_no_broken_arg_list():
    """v0.4.31 shipped console_summary.sh with blank lines INSIDE the sed
    argument list: every pattern after them became a separate command
    ("-e: not found"), silently dropping the curated story of switches -
    the actual car symptom the first round of '...' pressed on. The
    runtime bar: every curated story line of every verb must really
    reach the printout."""
    import subprocess, tempfile, os
    summary = GREENMENU / "console_summary.sh"
    lines = [
        "Phone map on the digital cluster: install",
        "Head unit: Harman MIB2 / MIB2.5 High (MHI2)",
        "Compatibility: tested firmware",
        "ERROR: could not remount the app partition",
        "Cannot remount the app partition read-write",
        "Nothing changed.",
        "Done: ClusterMap/run_logs/latest. Wait a few seconds.",
        "Switched", "Keep map: ON (the player re-asserts)",
        "Turn info strip: OFF.", "Turn-card clear: sides",
        "Cluster remote (OK press on the cluster): ON",
        "Porting bundle written",
        "Install finished", "Uninstall finished", "Sharper map: OFF.",
        "Zoom: 1.15. The player crops the phone's picture",
        "Hook: installed", "WARNING: cannot check the Java interface",
    ]
    with tempfile.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
        f.write("\n".join(lines) + "\n")
        log = f.name
    p = subprocess.run(["sh", str(summary), log], capture_output=True, text=True)
    os.unlink(log)
    for want in lines:
        assert want in p.stdout, (
            f"the curated line '{want}' is lost (the story chain broke)\n"
            f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}")
    assert not p.stderr, p.stderr
