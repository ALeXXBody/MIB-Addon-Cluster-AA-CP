"""Script-side audit tests (v0.5.2 rewrite of the mangled editor round):
the menu's script surface must be free of dead names and the verdict
chain must be parseable and complete (the owner's car caught a TRUNCATED
run_verdict.sh with "no closing quote" - a parse error no test caught
before, because the content tests only matched early-line snippets)."""
import pathlib
import re
import subprocess
import os

GREENMENU = pathlib.Path(
    "/tmp/opencode/mib2/mib-mod-repo/mod/cluster_map_aa_greenmenu/greenmenu")


def _menus_case():
    menus = (GREENMENU / "menus.sh").read_text()
    return menus.split('case "$1" in', 1)[1]


def _dispatcher_files():
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
        assert (GREENMENU / rel[len("greenmenu/"):]).is_file(), rel


def test_wrappers_resolve_to_scripts_that_exist():
    case = _menus_case()
    wrappers = sorted((GREENMENU / "gem").glob("*.sh"))
    assert wrappers, "no gem wrappers in the payload"
    block_cache = {}
    lines = case.splitlines()
    for i, l in enumerate(lines):
        s_ = l.strip()
        m = re.match(r"^([a-zA-Z_][a-zA-Z_0-9]*)\)", s_)
        if m:
            key = m.group(1)
        if s_ == ";;":
            block_cache.setdefault("LAST", None)
    # collect verb blocks properly: <verb>) ... ;; on one or more lines
    blocks, cur, name = {}, [], None
    for l in lines:
        s_ = l.strip()
        m = re.match(r"^([a-zA-Z_][a-zA-Z_0-9]*)\)", s_)
        if m and name is None:
            name = m.group(1)
        if name is not None:
            cur.append(l)
            if ";;" in s_:
                blocks[name] = "\n".join(cur)
                cur, name = [], None
    for w in wrappers:
        body = w.read_text()
        m = re.search(r'menus\.sh" ([a-z_]+(?: [a-z_.0-9]+)?)', body)
        assert m, f"{w.name} does not call the dispatcher"
        parts = m.group(1).split()
        verb = parts[0]
        assert verb in blocks, f"{w.name} -> verb '{verb}' not in menus.sh"
        hits = re.findall(r'\$HERE/([A-Za-z0-9_.-]+\.sh)', blocks[verb])
        assert hits or verb in ("diag", "logs"), (
            f"{w.name} -> '{verb}' resolves to no named file")
        for f in hits:
            assert (GREENMENU / f).is_file(), (
                f"{w.name} -> '{verb}' -> {f} MISSING on the card")


def test_console_summary_has_no_broken_arg_list():
    """v0.4.31 shipped console_summary.sh with blank lines INSIDE the sed
    argument list: every pattern after them became a separate command
    ("-e: not found"), silently dropping the curated story of switches -
    the car symptom behind the first '...' report. The runtime bar:
    every curated story line of every verb must really reach the print."""
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
    import tempfile as _t
    with _t.NamedTemporaryFile("w", suffix=".log", delete=False) as f:
        f.write("\n".join(lines) + "\n")
        log = f.name
    p = subprocess.run(["sh", str(summary), log],
                       capture_output=True, text=True)
    os.unlink(log)
    for want in lines:
        assert want in p.stdout, (
            f"the curated line '{want}' is lost (the story chain broke)\n"
            f"--stdout--\n{p.stdout}\n--stderr--\n{p.stderr}")
    assert not p.stderr, p.stderr


def test_every_press_carries_the_execution_proof_line():
    body = (GREENMENU / "run_verdict.sh").read_text()
    assert 'echo "ClusterMap $VERB ran / payload on card:' in body


def test_every_entry_ends_with_an_outcome_and_next_instruction():
    """run_verdict.sh must be COMPLETE and parseable: every branch of the
    dispatcher's verbs is a BODY, both outcomes exist, the case closes,
    and the exit contract (1 on a failing log) is honoured - the runner
    relies on that to show the run's ERROR lines. (The owner's car found
    a truncated file with 'no closing quote' - this test exists so that
    class cannot pass the gate again.)"""
    body = (GREENMENU / "run_verdict.sh").read_text()
    for verb in ("logs", "install", "arm", "uninstall", "tbt", "porting",
                 "portfull", "status", "verify", "diag",
                 "full_frame_on", "full_frame_off"):
        assert f"    {verb})" in body, f"verdict has no branch for {verb}"
    assert re.search(r'^echo "== DONE"$', body, re.M)
    assert re.search(r'^\s*echo "== STOPPED', body, re.M)
    assert re.search(r"\bexit 1\b", body) and re.search(r"\bexit 0\b", body)
    import tempfile as _t
    for text, want in (("FAIL:$x", 1), ("helpful line", 0)):
        with _t.NamedTemporaryFile("w", suffix=".log") as f:
            f.write(text + "; " + text)
            f.flush()
            proc = subprocess.run(
                ["sh", str(GREENMENU / "run_verdict.sh"), "install", f.name],
                capture_output=True, text=True)
        assert proc.returncode == want, (text, proc.stdout, proc.stderr)
    menus = (GREENMENU / "menus.sh").read_text()
    assert 'sh "$HERE/run_verdict.sh" "$1" "$_log"' in menus
    assert "-- the run's ERROR lines:" in menus
    assert 'sh "$HERE/console_summary.sh" "$_log"' in menus
