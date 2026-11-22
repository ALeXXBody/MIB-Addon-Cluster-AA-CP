"""Wheel switches: the listener start/stop and the tracer scoping.

wheel_listen.sh owns /tmp/gal_wheellisten (the flag) plus the listener
process; wheel_tracer.sh owns the HMI traceConfig.properties appenders.
Both must fail LOUD (rc!=0 with their own reason, or rc=3 "Nothing
changed") and never invent config the unit did not already carry.
"""
import os
import pathlib
import shutil
import subprocess
import time

import pytest

from conftest import APP_VIEWS, REPO, SYS_VIEWS

PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
SW = f"{PKG}/greenmenu"

LISTENER_STUB = "#!/bin/sh\nexec sleep 20\n"
TRACER_CONF = ("#activate.extension=ctrl,DSIKeyPanelEx\n"
               "#org.dsi.ifc.keypanel.DSIKeyPanel=small\n"
               "#org.dsi.ifc.keypanel.DSIKeyPanel=full\n"
               "use.appender=client\n")


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


def _conf_text():
    return pathlib.Path(APP_VIEWS[0],
                        "eso/lib/gal_dualscreen/gal_dualscreen.conf").read_text()


def test_listen_on_starts_daemon_and_persists(car):
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/wheel_listen",
              LISTENER_STUB, 0o755)

    p = _run(car, f"{SW}/wheel_listen.sh", "on", expect_rc=0)
    assert "Wheel listen: ON" in p.stdout, p.stdout + p.stderr
    assert (rt / "gal_wheellisten").read_text() == "1\n"
    pid = int((rt / "gal_wheellisten.pid").read_text().strip())
    os.kill(pid, 0)  # the stub really runs
    assert "GAL_WHEEL_LISTEN=1" in _conf_text()

    p = _run(car, f"{SW}/wheel_listen.sh", "off", expect_rc=0)
    assert "Wheel listen: OFF" in p.stdout, p.stdout + p.stderr
    assert (rt / "gal_wheellisten").read_text() == "0\n"
    assert not (rt / "gal_wheellisten.pid").exists()
    with pytest.raises(ProcessLookupError):
        os.kill(pid, 0)
    assert "GAL_WHEEL_LISTEN=0" in _conf_text()


def test_listen_on_reports_a_daemon_that_dies_at_once(car):
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/wheel_listen",
              "#!/bin/sh\nexit 0\n", 0o755)
    p = _run(car, f"{SW}/wheel_listen.sh", "on", expect_rc=1)
    assert "FAIL: wheel listener died on start" in p.stdout, \
        p.stdout + p.stderr
    assert (rt / "gal_wheellisten").read_text() == "0\n", \
        "a dead start must not leave the arm flag behind"


def test_listen_on_refuses_without_a_binary(car):
    _stage(car)
    rt = _rt()
    p = _run(car, f"{SW}/wheel_listen.sh", "on", expect_rc=3)
    assert "Nothing changed" in p.stdout, p.stdout + p.stderr
    assert not (rt / "gal_wheellisten").exists(), \
        "a refused arm must not leave a live flag behind"


def test_tracer_on_extends_appender_and_off_restores(car):
    _stage(car)
    _rt()
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties", TRACER_CONF)

    p = _run(car, f"{SW}/wheel_tracer.sh", "on", expect_rc=0)
    assert "Wheel tracer: ON" in p.stdout, p.stdout + p.stderr
    cfg = pathlib.Path(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties")
    assert cfg.read_text().count("use.appender=") == 1, \
        "the appender line is rewritten, never duplicated"
    assert "telnet" in cfg.read_text() and "bluepirat" in cfg.read_text()
    assert "org.dsi.ifc.keypanel.DSIKeyPanel=full\n" in cfg.read_text(), \
        "the unit's own commented scope line is flipped to full"
    assert "#org.dsi.ifc.keypanel" not in cfg.read_text(), \
        "no commented keypanel twin may survive (last-wins would be a guess)"
    # CAR PROOF (owner diag after 100+ reboots): the tracer ports stayed
    # silent because activate.extension was still commented - the HMI
    # only starts its tracer extension machinery (telnet/bluepirat
    # endpoints) with that line active. Flip it IN PLACE (keep its
    # position in the file).
    assert "activate.extension=ctrl,DSIKeyPanelEx\n" in cfg.read_text(), \
        f"the activation line must be uncommented:\n{cfg.read_text()}"
    assert "\n#activate.extension" not in cfg.read_text(), \
        "no commented activation twin may survive"
    assert (cfg.parent / "traceConfig.properties.orig").read_text() == TRACER_CONF
    assert (cfg.parent / "dsitracer_activated").exists()

    p = _run(car, f"{SW}/wheel_tracer.sh", "off", expect_rc=0)
    assert "Wheel tracer: OFF" in p.stdout, p.stdout + p.stderr
    assert cfg.read_text() == TRACER_CONF, "off restores the .orig byte-equal"
    assert not (cfg.parent / "dsitracer_activated").exists()


def test_control_on_repairs_dead_wheel(car):
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties", TRACER_CONF)
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/wheel_listen",
              LISTENER_STUB, 0o755)

    p = _run(car, f"{SW}/wheel_control.sh", "on", expect_rc=0)
    assert "Wheel control: ON" in p.stdout, p.stdout + p.stderr
    assert (rt / "gal_wheellisten").read_text() == "1\n"
    cfg = pathlib.Path(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties")
    assert "telnet" in cfg.read_text() and "bluepirat" in cfg.read_text()
    pid = int((rt / "gal_wheellisten.pid").read_text().strip())
    os.kill(pid, 0)


def test_control_off_reverts_everything(car):
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties", TRACER_CONF)
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/wheel_listen",
              LISTENER_STUB, 0o755)
    _run(car, f"{SW}/wheel_control.sh", "on", expect_rc=0)

    p = _run(car, f"{SW}/wheel_control.sh", "off", expect_rc=0)
    assert "Wheel control: OFF" in p.stdout, p.stdout + p.stderr
    assert (rt / "gal_wheellisten").read_text() == "0\n"
    cfg = pathlib.Path(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties")
    assert cfg.read_text() == TRACER_CONF
    assert not (cfg.parent / "dsitracer_activated").exists()


def test_states_row_refreshes_on_the_main_menu(car):
    _stage(car)
    rt = _rt()
    screen = ('screen ClusterMap Main\n'
              '\n'
              'keyValue\n'
              '    value   String sys 0x00000000 0\n'
              '    label   "States: --"\n'
              '    poll    0\n')
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/engdefs/cluster-map.esd", screen)
    # through the GEM wrapper, exactly like the car (the refresh lives in
    # menus.sh run_quiet, not in the switch itself)
    _run(car, f"{SW}/gem/remote_on.sh", expect_rc=0)
    for v in APP_VIEWS:
        text = pathlib.Path(v, "eso/hmi/engdefs/cluster-map.esd").read_text()
        assert 'label   "States: remote' in text, \
            f"main menu not refreshed through {v}:\n{text}"
        assert "screen ClusterMap" in text


def test_states_row_survives_a_reboot_from_conf(car):
    """After a reboot /tmp (and the live flags) is wiped: the row must
    still show what the persisted settings say (remote/strip/pump)."""
    _stage(car)
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/gal_dualscreen.conf",
              "GAL_PLAYER_WINDOW=1010x376\n"
              "GAL_CLUSTER_REMOTE=1\n"
              "GAL_NAV_INFO_STRIP=1\n"
              "GAL_IDR_PUMP=25\n"
              "GAL_WHEEL_LISTEN=0\n")
    rt = _rt()  # empty: no live flags, as after a reboot
    screen = ('screen ClusterMap Main\n'
              '\n'
              'keyValue\n'
              '    value   String sys 0x00000000 0\n'
              '    label   "States: stock (all off)"\n'
              '    poll    0\n')
    for v in (APP_VIEWS[0],):
        car.stage(v, "eso/hmi/engdefs/cluster-map.esd", screen)
    p = car.run(["sh", f"{SW}/gem/status.sh"], env={"GAL_RUNTIME_DIR": str(rt)},
                expect_rc=0)
    assert p.returncode == 0
    text = pathlib.Path(APP_VIEWS[0],
                        "eso/hmi/engdefs/cluster-map.esd").read_text()
    assert 'label   "States: remote, strip, pump"' in text, \
        f"persisted states lost after reboot-shape run:\n{text}"


def test_status_lists_every_family_compactly(car):
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/gal_dualscreen.conf",
              "GAL_PLAYER_WINDOW=1010x376\n"
              "GAL_CLUSTER_REMOTE=1\n"
              "GAL_CLUSTER_MENU=1\n"
              "GAL_IDR_PUMP=25\n"
              "GAL_WHEEL_LISTEN=0\n")
    (rt / "gal_hires").write_text("1\n")
    (rt / "gal_idr_pump").write_text("25\n")
    p = _run(car, f"{SW}/status.sh", expect_rc=0)
    for line in ("Features (setting -> when it lands):",
                 "Cluster remote: ON (no session yet)",
                 "Wheel control: OFF",
                 "Cluster menu: ON (no session yet)",
                 "Hi-res: ON (next session)",
                 "Pump: 25s (live)"):
        assert line in p.stdout, f"{line!r} missing:\n{p.stdout}"


def test_status_marks_dead_aa_path_idle(car):
    """The remote/menu/tap trio feeds only on outbound 0x8001 reports.
    A hook log full of session traffic but zero 0x8001 must say idle,
    not live; a single 0x8001 line flips it back."""
    _stage(car)
    rt = _rt()
    car.stage(APP_VIEWS[0], "eso/lib/gal_dualscreen/gal_dualscreen.conf",
              "GAL_PLAYER_WINDOW=1010x376\n"
              "GAL_CLUSTER_REMOTE=1\n"
              "GAL_CLUSTER_MENU=1\n")
    hooklog = rt / "hook.log"
    hooklog.write_text("gal_dualscreen t=26.098 event=aap.out msg_id=0x0003\n"
                       "gal_dualscreen t=26.405 event=aap.out msg_id=0x8003\n")
    p = _run(car, f"{SW}/status.sh", env={"GAL_HOOK_LOG": str(hooklog)},
             expect_rc=0)
    assert "Cluster remote: ON (idle: no wheel reports)" in p.stdout, p.stdout
    assert "Cluster menu: ON (idle: no wheel reports)" in p.stdout, p.stdout
    with open(hooklog, "a") as f:
        f.write("gal_dualscreen t=30.1 event=aap.out msg_id=0x8001 bytes=9\n")
    p = _run(car, f"{SW}/status.sh", env={"GAL_HOOK_LOG": str(hooklog)},
             expect_rc=0)
    assert "Cluster remote: ON (live)" in p.stdout, p.stdout


def test_press_stays_green_without_any_screen_file(car):
    _stage(car)
    _rt()
    p = _run(car, f"{SW}/cluster_remote.sh", "on", expect_rc=0)
    assert "Cluster remote: ON" in p.stdout, p.stdout + p.stderr


def test_tracer_on_refuses_without_an_appender_key(car):
    _stage(car)
    _rt()
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties",
              "# no appender key here\norg.dsi.ifc.keypanel=all\n")
    p = _run(car, f"{SW}/wheel_tracer.sh", "on", expect_rc=3)
    assert "Nothing changed" in p.stdout, p.stdout + p.stderr
