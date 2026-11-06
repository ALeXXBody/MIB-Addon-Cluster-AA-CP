"""Static regression guards for the GEM screen/consistency surfaces that the
sim cannot reach end-to-end (custom.sh's own engdefs view pick, exactly the
line the owner caught hardcoding /net/mmx/...)."""
import pathlib
import re

REPO = pathlib.Path("/tmp/opencode/mib2/mib-mod-repo")
CUSTOM = REPO / "mod/custom.sh"


def test_engdefs_view_candidates_fqdn_first():
    s = CUSTOM.read_text()
    fqdn = s.find("/net/mmx.mibhigh.net/mnt/app")
    short = s.find("/net/mmx/mnt/app")
    assert fqdn != -1 and short != -1, "view candidates missing entirely"
    assert fqdn < short, "the FQDN spelling must be probed before the shorthand"


def test_engdefs_no_bare_hardcode_without_probe():
    s = CUSTOM.read_text()
    lines = s.splitlines()
    for i, l in enumerate(lines):
        if re.search(r'^\s*ENGDEFS=__CONSTANT__="__CONSTANT__/nope"', l):
            raise AssertionError(l)
    bad = [l for l in lines
           if re.match(r'\s*ENGDEFS=/net/mmx/mnt/app', l)]
    assert not bad, f"hardcoded ENGDEFS without a view probe: {bad}"
    assert "ENGDEFS: writable via" in s or "engdefs: writable via" in s, \
        "custom.sh must report which view spelling won"


def test_custom_selfcheck_covers_all_app_views():
    s = CUSTOM.read_text()
    loop = re.search(r'for _view in (.*)\n', s)
    assert loop, "self-check view loop missing"
    for v in ("/mnt/app", "/net/mmx.mibhigh.net/mnt/app", "/net/mmx/mnt/app", "/net/rcc/mnt/app"):
        assert v in s, f"self-check missing view {v}"


def test_no_bare_grep_o_or_printf_in_unit_scripts():
    bad = []
    for f in list(REPO.glob("mod/**/*.sh")):
        if "experiments" in str(f) or "car_sim" in str(f):
            continue
        text = f.read_text()
        for m in re.finditer(r'^[^#\n]*\bprintf\b|^[^#\n]*\bgrep -o\b|^[^#\n]*\btr -d\b',
                             text, re.M):
            g = m.group(0)
            if "command -v" in g or "Note:" in g or re.search(r'for t in printf', g):
                continue
            bad.append((f.name, m.group(0).strip()))
    assert not bad, f"missing-tool usage crept back in: {bad}"
