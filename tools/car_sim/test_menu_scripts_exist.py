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
