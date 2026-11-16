"""wheel_listen contract: the steering-wheel client must turn the HMI DSI
tracer lines into the player's own zoom/card/strip files, exactly like
the hook's bound gestures do -- and log everything else without acting.

The client is dual-mode C (sources/tools/wheel_listen.c): the unit build
talks sockets, the host test driver (-DWL_TEST_MAIN) reads canned
transcript lines on stdin and prints the actions the live loop would
take, sandboxing file writes by basename into $WL_TEST_TMPDIR. These
tests compile the driver once with the host gcc and feed it the
car-proven line shapes (joeyQuery/MHI2-altScreen TRACE-015:
1#...DSIKeyPanelListener#updateEncoder2#ts|int:4|int:40|int:+1|...,
bluepirat "<seq>?1#..." wrappers, updateKey2 short/long sequences).
"""
import os
import pathlib
import shutil
import subprocess

import pytest

REPO = pathlib.Path(__file__).resolve().parents[2]
SRC = REPO / "sources/tools/wheel_listen.c"

ENC_UP = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
          "#updateEncoder2#1690000001|int:4|int:40|int:+1|int:0|int:1")
ENC_DOWN = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
            "#updateEncoder2#1690000002|int:4|int:40|int:-1|int:0|int:1")
ENC_DUP = ("5#org.dsi.ifc.keypanel.DSIKeyPanelListener"
           "#updateEncoder2#1690000003|int:4|int:40|int:+1|int:0|int:1")
ENC_BP = ("12?1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
          "#updateEncoder2#1690000004|int:4|int:40|int:-1|int:0|int:1")
KEY_DOWN = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
            "#updateKey2#1690000010|int:4|int:40|int:1|int:0|int:0")
KEY_UP = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
          "#updateKey2#1690000011|int:4|int:40|int:0|int:0|int:0")
KEY_LONG = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
            "#updateKey2#1690000020|int:4|int:40|int:3|int:0|int:0")
KEY_VIEW = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
            "#updateKey2#1690000030|int:4|int:35|int:1|int:0|int:0")
KEY_VC99 = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
            "#updateKey2#1690000031|int:4|int:99|int:1|int:0|int:0")
KEY_VC100 = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
             "#updateKey2#1690000032|int:4|int:100|int:1|int:0|int:0")


@pytest.fixture(scope="module")
def driver(tmp_path_factory):
    if shutil.which("gcc") is None:
        pytest.skip("host gcc not available")
    outdir = tmp_path_factory.mktemp("wlbuild")
    exe = outdir / "wltest"
    proc = subprocess.run(
        ["gcc", "-DWL_TEST_MAIN", "-O2", "-Wall", "-Wextra",
         "-std=gnu99", str(SRC), "-o", str(exe)],
        capture_output=True, text=True)
    assert proc.returncode == 0, f"host driver build failed:\n{proc.stderr}"
    return exe


_FEED_N = [0]


def _feed(driver, tmp_path, lines, start=None):
    _FEED_N[0] += 1
    sandbox = tmp_path / f"wl{_FEED_N[0]}"
    sandbox.mkdir()
    env = dict(os.environ, WL_TEST_TMPDIR=str(sandbox))
    if start is not None:
        env["WL_TEST_START"] = start
    proc = subprocess.run([str(driver)], input="\n".join(lines) + "\n",
                          capture_output=True, text=True, env=env)
    assert proc.returncode == 0, f"driver died:\n{proc.stderr}"
    return proc.stdout.splitlines(), sandbox


def test_rotary_notches_drive_zoom_and_dupes_ignored(driver, tmp_path):
    out, box = _feed(driver, tmp_path,
                     [ENC_UP, ENC_UP, ENC_DUP, ENC_BP])
    zooms = [l for l in out if l.startswith("ZOOM")]
    # two live notches up, the 5# duplicate ignored, bluepirat notch down
    assert zooms == ["ZOOM +1 1.13", "ZOOM +1 1.26", "ZOOM -1 1.13"], out
    assert (box / "stream-player.zoom").read_text() == "1.13\n"


def test_zoom_clamps_at_both_ends(driver, tmp_path):
    out, box = _feed(driver, tmp_path, [ENC_UP] * 10)
    assert out[-2] == "ZOOM +1 1.35"
    assert (box / "stream-player.zoom").read_text() == "1.35\n"
    out, box = _feed(driver, tmp_path, [ENC_DOWN] * 10, start="1.35")
    assert out[-2] == "ZOOM -1 1.00"
    assert (box / "stream-player.zoom").read_text() == "1.00\n"


def test_short_press_resolves_short_and_latch_resets(driver, tmp_path):
    # long THEN short: the latch must clear on release, not stick
    out, _ = _feed(driver, tmp_path, [KEY_LONG, KEY_UP, KEY_DOWN, KEY_UP])
    keys = [l for l in out if l.startswith("KEY")]
    assert keys == ["KEY-LOG-ONLY", "KEYUP-LONG", "KEYDOWN", "KEYUP-SHORT"], out


def test_long_press_state4_also_arms(driver, tmp_path):
    state4 = KEY_LONG.replace("|int:3|", "|int:4|")
    out, _ = _feed(driver, tmp_path, [state4, KEY_UP])
    keys = [l for l in out if l.startswith("KEY")]
    assert keys == ["KEY-LOG-ONLY", "KEYUP-LONG"], out


def test_view_vc_and_unknown_are_log_only(driver, tmp_path):
    other = ("1#org.dsi.ifc.keypanel.DSIKeyPanelListener"
             "#updateKey2#1690000040|int:4|int:41|int:1|int:0|int:0")
    out, box = _feed(driver, tmp_path,
                     [KEY_VIEW, KEY_VC99, KEY_VC100, other, "noise line"])
    assert "KEY-VIEW" in out, out
    assert "KEY-VCLEFT" in out, out
    assert "KEY-VCRIGHT" in out, out
    assert "KEY-LOG-ONLY" in out, out  # unknown key shape: logged, no action
    assert "IGNORE" in out, out  # non-tracer line: not even logged
    assert not (box / "stream-player.zoom").exists()
    log = (box / "gal_wheel.log").read_text()
    for needle in ("int:35", "int:99", "int:100", "int:41"):
        assert needle in log, log
    assert "noise line" not in log


def test_writes_are_atomic_no_staging_leftovers(driver, tmp_path):
    _, box = _feed(driver, tmp_path, [ENC_UP, ENC_UP, ENC_DOWN])
    leftovers = list(box.glob("*.new"))
    assert leftovers == [], [p.name for p in leftovers]
    assert (box / "stream-player.zoom").read_text() == "1.13\n"
