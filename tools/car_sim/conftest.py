"""Shared car-simulation fixtures.

Only meaningful when run through tools/car_sim/runner.sh (private mount
namespace where /mnt, /net, /fs and /sim are tmpfs shadows). The unit's
view spellings are built with REAL filesystem semantics:

* read-write views are rw tmpfs mounts of individual view dirs, so the
  scripts' real `mount -uw` calls succeed there and the probes pass;
* read-only views are ro tmpfs mounts, so `mount -uw` fails with EROFS
  and every write probe fails the way a GEM console behaves on a node
  whose view of a partition is read-only.
"""
import os
import pathlib
import shutil
import subprocess
import sys
import textwrap

import pytest

REPO = pathlib.Path(__file__).resolve().parents[2]
PAYLOAD = REPO / "mod" / "cluster_map_aa_greenmenu"

APP_VIEWS = ["/mnt/app", "/net/mmx.mibhigh.net/mnt/app", "/net/mmx/mnt/app", "/net/rcc/mnt/app"]
SYS_VIEWS = ["/mnt/system", "/net/mmx.mibhigh.net/mnt/system", "/net/mmx/mnt/system", "/net/rcc/mnt/system"]
CARD_VIEWS = ["/fs/sda0", "/fs/sdb0", "/net/mmx/fs/sda0", "/net/mmx.mibhigh.net/fs/sda0"]

VERSION_TXT = "Current train = MHI2_ER_VWG13_P4521\n"
JSONLINT_SH = "#!/bin/sh\nexit 0\n"
ON_FAIL_SH = "#!/bin/sh\nexit 1\n"  # no cross-node remount in the sim


def _mount_tmpfs(view, ro=False):
    assert view.startswith(("/mnt/", "/net/", "/fs/")), view
    pathlib.Path(view).mkdir(parents=True, exist_ok=True)
    opts = ["-t", "tmpfs", "-o", f"size=32m,mode=755{',ro' if ro else ''}"]
    subprocess.run(["mount", *opts, "tmpfs", view], check=True)


def _remount_ro(view):
    """Put a view on a genuinely READ-ONLY mount — bypasses the mount CLI
    stub entirely (direct mount(2) call), so probes through that view fail
    exactly like a read-only console view."""
    import ctypes
    libc = ctypes.CDLL(None, use_errno=True)
    MS_RDONLY = 1
    MS_REMOUNT = 32
    rc = libc.mount(None, view.encode(), None, MS_REMOUNT | MS_RDONLY, None)
    if rc != 0:
        # First create a ro overlay if the view was never a real mount,
        # e.g. when tests made plain dirs on the namespace's base tmpfs:
        # mount a fresh ro tmpfs stacked on top instead.
        opts = ["-t", "tmpfs", "-o", "size=32m,mode=755,ro", "tmpfs", view]
        subprocess.run(["mount", *opts], check=True)


class Car:
    """State per test: view mounts, staged paths, script runner."""

    def __init__(self, name):
        self.name = name
        self._tmp = pathlib.Path("/sim") / name
        self._tmp.mkdir(parents=True, exist_ok=True)

    # ---- view construction -------------------------------------------------
    def mkdir_views(self, views):
        for v in views:
            pathlib.Path(v).mkdir(parents=True, exist_ok=True)

    def mount_views(self, rw=(), ro=()):
        for v in rw:
            _mount_tmpfs(v, ro=False)
        for v in ro:
            # ro views never got content yet; a fresh ro tmpfs stack is a
            # read-only view for every later probe.
            _mount_tmpfs(v, ro=True)

    def make_read_only(self, view):
        """Emulate a view the console cannot write to, for every probe name
        the payload scripts use (.clustermap_rw_probe for the app ladder,
        .clustermap_probe for the system ladder, .clustermap_restore_probe
        for the restore ladder): a pre-existing file of that name makes each
        `mkdir` fail deterministically (EEXIST) on any filesystem, while
        READ-side use (config reads, jsonlint, manifests) keeps working —
        exactly a console that can see a partition but not write it. (A
        genuinely ro tmpfs cannot be used: this kernel refuses tmpfs
        remounts with the container's userns mapping.)"""
        # a directory at each probe name: the payload's write probes are
        # now FILE writes (`: > probe`, mkdir is refused on the real
        # unit), so a DIRECTORY is the deterministic "not writable here".
        # The v0.7.5 probes live at the WRITE TARGETS, so block those too:
        #   app    -> $view/eso/lib/gal_dualscreen/.clustermap_rw_probe
        #   system -> $view/etc/eso/production/.clustermap_sys_probe
        #   card   -> $view/.galconf_probe  (conf_card_write's own probe)
        probes = (".clustermap_rw_probe", ".clustermap_probe",
                  ".clustermap_restore_probe", ".galconf_probe",
                  ".clustermap_sys_probe")
        for probe in probes:
            (pathlib.Path(view, probe)).mkdir(parents=True, exist_ok=True)
        for sub in ("eso/lib/gal_dualscreen", "etc/eso/production"):
            for probe in (".clustermap_rw_probe", ".clustermap_sys_probe",
                          ".clustermap_probe"):
                (pathlib.Path(view, sub, probe)).mkdir(parents=True,
                                                      exist_ok=True)

    def stage(self, view, rel, content=b"", mode=None):
        """Stage <content> at <view>/<rel>; missing parents are created."""
        p = pathlib.Path(view, rel)
        p.parent.mkdir(parents=True, exist_ok=True)
        if isinstance(content, str):
            content = content.encode()
        if isinstance(content, pathlib.Path):
            shutil.copyfile(content, p)
        else:
            p.write_bytes(content)
        if mode is not None:
            p.chmod(mode)
        return p

    def stage_payload_on_card(self, rel="mod/cluster_map_aa_greenmenu", card="/fs/sda0"):
        """Copy the repo payload onto the (in-namespace) card view."""
        dst = pathlib.Path(card, rel)
        if dst.exists():
            shutil.rmtree(dst)
        dst.mkdir(parents=True)
        shutil.copytree(PAYLOAD, dst, dirs_exist_ok=True)
        # Unit-only execution stages: jsonlint/`on` do not exist in the sim;
        # the payload's scripts must reach them through the APP view ladder.
        return dst

    def stage_jsonlint_all_app_views(self):
        """Drop a harmless jsonlint stand-in into every EXISTING app view."""
        for v in APP_VIEWS:
            if pathlib.Path(v).exists():
                self.stage(v, "eso/bin/jsonlint", JSONLINT_SH, 0o755)

    def stage_version(self, node="rcc"):
        self.stage(f"/net/{node}/dev/shmem", "version.txt", VERSION_TXT)

    def stage_lsd(self, view):
        return self.stage(view, "eso/hmi/lsd/lsd.sh", "# lsd stub\n")

    # ---- running scripts ---------------------------------------------------
    def run(self, argv, cwd=None, env=None, expect_rc=None):
        e = dict(os.environ)
        e.setdefault("PATH", "/bin:/bin:/usr/bin")
        e.setdefault("CB_MOUNT_TABLE",
                     "/net/mmx.mibhigh.net/dev/sda0t12 on /fs/sda0 type dos (fat32)")
        if env:
            e.update(env)
        proc = subprocess.run(argv, cwd=str(cwd) if cwd else None, env=e,
                              capture_output=True, text=True, timeout=120)
        if expect_rc is not None:
            assert proc.returncode == expect_rc, (
                f"rc={proc.returncode} (want {expect_rc})\n"
                f"--- stdout ---\n{proc.stdout}\n--- stderr ---\n{proc.stderr}")
        return proc


@pytest.fixture
def car(tmp_path):
    """A fresh Car bound to a unique name under the /sim tmpfs."""
    name = tmp_path.name
    return Car(name)


@pytest.fixture(autouse=True)
def _car_clean_slate():
    """Unit views are tmpfs shadows, but any stragglers from an earlier run
    in the same namespace must not leak between tests: unmount leftovers."""
    # Each test mounts its own tmpfs on the shared view paths; tmpfs mounts
    # stack, so ensure the view dirs START empty: mount one fresh tmpfs on
    # top and keep a record so teardown can pop it.
    stack = []
    yield
    import glob as _g
    # Pop any tmpfs mounts the test left on the shared paths (top-down).
    for view in ("fs/sda0", "fs/sdb0", "net/mmx/fs/sda0", "net/mmx/fs/sdb0",
                 "net/mmx.mibhigh.net/fs/sda0",
                 "mnt/app", "mnt/system",
                 "net/mmx.mibhigh.net/mnt/app", "net/mmx.mibhigh.net/mnt/system",
                 "net/mmx/mnt/app", "net/mmx/mnt/system",
                 "net/rcc/mnt/app", "net/rcc/mnt/system"):
        stack.append(view)
    for view in stack:
        # tmpfs mounts stack across tests in this shared namespace — pop
        # every one of them so the next test starts from a bare path.
        while subprocess.run(["umount", f"/{view}"], capture_output=True).returncode == 0:
            pass
        # Files/dirs created directly on the ABOUT-to-be-popped layer (the
        # runner's base tmpfs at /mnt,/net,/fs) must not leak either: they
        # live inside the namespace's tmpfs root, which is shredded when the
        # namespace exits, but tests run sequentially in it.
        shutil.rmtree(f"/{view}", ignore_errors=True)
    # M.I.B. writes under /tmp in the fallback home; clear between tests.
    shutil.rmtree("/tmp/clustermap_unit", ignore_errors=True)
    shutil.rmtree("/tmp/clustermap_diag", ignore_errors=True)
    for marker in ("/tmp/clustermap_last_paths", "/tmp/cm_custom.log"):
        p = pathlib.Path(marker)
        if p.exists():
            p.unlink()
