"""Static contract for the Hi-RES insets path (owner A/B, v0.7.39).

The old code called apply_video_config_insets() on the VideoSink itself;
the worker stores viewing_distance at +0x40, which on a sink is the
allowed-configuration VECTOR pointer, so HI-RES ON destroyed the sink's
config list and Android Auto died at the next session. The fix resolves
the freshly added 1280x720 VideoConfig and verifies its resolution enum
before touching it."""
import re

from conftest import REPO

SRC = REPO / "sources/src/video_sink_hook.c"


def test_hires_never_applies_insets_to_the_sink():
    s = SRC.read_text()
    assert "apply_video_config_insets(g_secondary_sink" not in s, \
        "the insets worker must never receive the sink (sink+0x40 is the " \
        "config-vector pointer; writing it kills the session)"


def test_hires_verifies_the_720p_entry_before_touching_it():
    s = SRC.read_text()
    i = s.find("hires_vec = load_u32(g_secondary_sink, 0x40u)")
    assert i > 0, "the guarded lookup is gone"
    block = s[i:i + 900]
    assert "load_u32((void *)hires_vec, 4u)" in block, "no vconf lookup"
    assert "load_u32(hires_vconf, 0x28u) == VIDEO_CODEC_RESOLUTION_1280_720" in block, \
        "the resolution enum must be verified before the worker runs"
    assert 'apply_video_config_insets(hires_vconf, &scaled, "hires")' in block, \
        "the guarded call is missing"
    assert "insets_skipped" in block, "a failed lookup must be logged, not silent"


def test_base_insets_path_unchanged():
    """The corruption fix must not touch the working base path."""
    s = SRC.read_text()
    assert 'apply_video_config_insets(vconf, config, "build_sink")' in s
    assert 'apply_video_config_insets(vconf_array[0], gal_hook_config(), "discovery")' in s
