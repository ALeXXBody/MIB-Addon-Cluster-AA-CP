"""The omonob MFW capture jar path (GPL-3.0, shipped unmodified).

CAR FACTS (owner diags v0.7.39-v0.7.41): the production HMI never runs
the DSI tracer endpoints (activation line active, HMI restarted, ports
1798/20991 still silent) and this firmware never emits 0x8001 input
reports (8 sessions). The working path on the same hardware family is
omonob's CarPlayClusterControls.jar: a bootclasspath-patched
DSIKeyPanelDispatcher receives the MFW keys in the Java layer and sends
plain-ASCII datagrams ("canvas-zoom-in/out/noop") to 127.0.0.1:7032/7033.
Wheel control ON installs the jar through lsd_jar.sh (the mechanism this
unit already proves with NavActiveIgnore), marked; OFF removes it. The
listener binds the datagram ports and acts on zoom, logging the rest.
"""
import pathlib
import shutil
import zipfile

from conftest import APP_VIEWS, REPO, SYS_VIEWS

PAYLOAD_SRC = REPO / "mod/cluster_map_aa_greenmenu"
PKG = "/fs/sda0/mod/cluster_aa"
SYS_CFG = "etc/eso/production/smartphone_integrator.json"
JAR_LINE = "CarPlayClusterControls.jar"


def _stage(car):
    dst = pathlib.Path(PKG)
    dst.mkdir(parents=True, exist_ok=True)
    shutil.copytree(PAYLOAD_SRC, dst, dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns("SHA256SUMS.txt", "LICENSE"))
    car.mount_views(rw=[*APP_VIEWS, *SYS_VIEWS])
    car.stage_jsonlint_all_app_views()
    car.stage_version("rcc")
    for v in SYS_VIEWS:
        car.stage(v, SYS_CFG, '{\n "children": { "gal": { "envs":[] } }\n}\n')
    # the HMI's own lsd.sh must exist for lsd_jar.sh to edit it (same
    # minimal shape the lsd tests use)
    lines = (["#!/bin/sh", "BASE_DIR=/mnt/app"] +
             ["# pad %d" % i for i in range(120)] +
             ["FOO=Xbootclasspath/a:/ifs/lsd.jxe", "$J9 -jxe dummy"])
    for v in APP_VIEWS:
        car.stage(v, "eso/hmi/lsd/lsd.sh", "\n".join(lines) + "\n")
    return dst


def _run(car, script, arg):
    return car.run(["sh", f"{PKG}/greenmenu/{script}", arg], expect_rc=None)


def test_wheel_control_on_installs_the_capture_jar(car):
    _stage(car)
    p = _run(car, "wheel_control.sh", "on")
    # the jar helper edits the FIRST view that resolves (on the unit all
    # spellings are one partition; in the sim they are separate mounts)
    views = [pathlib.Path(v) for v in APP_VIEWS if
             pathlib.Path(v, "eso/hmi/lsd/lsd.sh").exists()]
    assert views, "no lsd.sh staged"
    lsd_views = [(v, (v / "eso/hmi/lsd/lsd.sh").read_text()) for v in views]
    hit = [v for v, t in lsd_views if JAR_LINE in t]
    assert hit, f"jar line missing from every view:\n{p.stdout}{p.stderr}\n{[t[:80] for _, t in lsd_views]}"
    v = hit[0]
    assert (v / "eso/hmi/lsd/jars/CarPlayClusterControls.jar").exists(), \
        "jar not staged"
    assert (v / "eso/hmi/lsd/.aacluster_wheeljar_added").exists(), \
        "our marker missing"
    # the jar is ours to remove again
    q = _run(car, "wheel_control.sh", "off")
    assert JAR_LINE not in (v / "eso/hmi/lsd/lsd.sh").read_text(), \
        "jar line survived OFF"
    assert not (v / "eso/hmi/lsd/jars/CarPlayClusterControls.jar").exists(), \
        "jar file survived OFF"
    assert not (v / "eso/hmi/lsd/.aacluster_wheeljar_added").exists()


def test_listener_binds_the_dispatcher_datagram_ports():
    """wheel_listen must bind 127.0.0.1:7032/7033 (the only two ports the
    jar's command() can emit on) and act on the zoom commands."""
    src = (REPO / "sources/tools/wheel_listen.c").read_text()
    assert "wl_udp_bind" in src
    assert "{ 7032, 7033 }" in src, "both dispatcher ports must be bound"
    assert '"canvas-zoom-in"' in src and '"canvas-zoom-out"' in src, \
        "the jar wire strings must be parsed"
    assert "recvfrom" in src, "datagram path missing"
    # the tracer path stays alongside the datagram path
    assert "1798" in src and "20991" in src


def test_jar_is_shipped_and_unmodified():
    """GPL compliance: the jar ships unmodified; its classes are the
    dispatcher replacement + bridge the research identified."""
    jar = PAYLOAD_SRC / "thirdparty/CarPlayClusterControls.jar"
    assert jar.is_file()
    with zipfile.ZipFile(jar) as z:
        names = z.namelist()
    assert "de/esolutions/fw/dsi/keypanel/DSIKeyPanelDispatcher.class" in names, \
        "the dispatcher replacement is the capture point"
    assert "de/vw/mib/carplay/clustercontrol/Mhi2ClusterControlBridge.class" in names
