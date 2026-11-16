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
TRACER_CONF = ("# HMI tracer config (staged)\n"
               "use.appender=client\n"
               "org.dsi.ifc.keypanel=all\n")


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
    assert (cfg.parent / "traceConfig.properties.orig").read_text() == TRACER_CONF
    assert (cfg.parent / "dsitracer_activated").exists()

    p = _run(car, f"{SW}/wheel_tracer.sh", "off", expect_rc=0)
    assert "Wheel tracer: OFF" in p.stdout, p.stdout + p.stderr
    assert cfg.read_text() == TRACER_CONF, "off restores the .orig byte-equal"
    assert not (cfg.parent / "dsitracer_activated").exists()


def test_tracer_on_refuses_without_an_appender_key(car):
    _stage(car)
    _rt()
    car.stage(APP_VIEWS[0], "eso/hmi/lsd/traceConfig.properties",
              "# no appender key here\norg.dsi.ifc.keypanel=all\n")
    p = _run(car, f"{SW}/wheel_tracer.sh", "on", expect_rc=3)
    assert "Nothing changed" in p.stdout, p.stdout + p.stderr
