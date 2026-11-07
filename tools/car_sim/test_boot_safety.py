"""Boot-safety variants: the armed install (explicit owner action) is the
only one that writes the hook's LD_PRELOAD into gal's supervisor config;
an M.I.B. CarPlay Maps VC stack is refused outright."""
import pathlib
import re
import shutil

from conftest import APP_VIEWS, SYS_VIEWS

import test_hook_lifecycle as base

PKG = base.PKG
PAYLOAD_SRC = base.PAYLOAD_SRC


def test_armed_install_injects_the_preload(car):
    """Only an explicitly-armed install (card marker or env) puts
    LD_PRELOAD=<hook> into the supervisor config."""
    base._stage(car)
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    sys_prod = "etc/eso/production/smartphone_integrator.json"
    json_cfg = (
        "{\n"
        ' "children": {\n'
        '  "gal": {\n'
        '   "envs":[]\n'
        "  }\n"
        " }\n"
        "}\n")
    for v in SYS_VIEWS:
        car.stage(v, sys_prod, json_cfg)
    for v in (APP_VIEWS[0], APP_VIEWS[2], APP_VIEWS[3],
              SYS_VIEWS[0], SYS_VIEWS[2], SYS_VIEWS[3]):
        car.make_read_only(v)
    # explicit arm marker on the card
    pathlib.Path(PKG, "HOOK_ARMED").write_text("")

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    out = p.stdout + p.stderr
    assert p.returncode == 0, f"--stdout--\n{out}"
    cfg = pathlib.Path(SYS_VIEWS[1], sys_prod)
    txt = cfg.read_text()
    assert "libgal_hook.so" in txt, f"armed install did not inject: {txt}"
    assert "GAL_DUALSCREEN_ENABLE=1" in txt, txt


def test_carplay_stack_refused(car):
    """M.I.B.'s own CarPlay Maps VC payload present -> refuse, touch nothing."""
    base._stage(car)
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    sys_prod = "etc/eso/production/smartphone_integrator.json"
    stacked = (
        "{\n"
        ' "children": {\n'
        '  "gal": {\n'
        '   "envs":["LD_PRELOAD=/eso/maps_vc/omonob.so"]\n'
        "  },\n"
        '  "carplaymaps": {}\n'
        " }\n"
        "}\n")
    for v in SYS_VIEWS:
        car.stage(v, sys_prod, stacked)
    for v in (APP_VIEWS[0], APP_VIEWS[2], APP_VIEWS[3],
              SYS_VIEWS[0], SYS_VIEWS[2], SYS_VIEWS[3]):
        car.make_read_only(v)

    p = car.run(["sh", f"{PKG}/enable_hook.sh"], expect_rc=None)
    assert p.returncode == 4, f"expected the stack refusal (rc 4), got {p.returncode}"
    out = p.stdout + p.stderr
    assert "One protocol per cluster" in out or "omonob" in out, out
    # the config must be untouched
    cfg = pathlib.Path(SYS_VIEWS[1], sys_prod)
    txt = cfg.read_text()
    assert "libgal_hook.so" not in txt, "refused install still injected!"
    assert "omonob" in txt, txt
