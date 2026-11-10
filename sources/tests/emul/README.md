# Emulated-unit test platform (fork)

Goal: run parts of this project against the **real binaries from a MHI2.5
High unit** (your Tiguan's `gal`, `dmdt`, `libautoreceiver.so`, `libairplay.so`,
EFS/configuration) *on your Linux host*, so improvements can be tested before
a car test. Three layers, each independently useful:

```text
Layer A  host tools (no emulation):      profile_check, nav_translate_test,
                                         dumpifs/imagefs readers
Layer B  QNX user-mode under QEMU:       the unit's own dmdt / gal / hooks
                                         (needs luka-dev's QNX 6.5 runtime)
Layer C  full-system (future):           a QEMU-system-arm Tegra board model
                                         booting procnto — research scale
```

## Layer A — already working, add more here

`git`-safe host tests that don't need firmware files:

```
.venv/bin/python tests/test_profile_check.py       # profiles.conf gate
cc -I src tests/nav_translate_test.c src/nav_translate.c -o /tmp/navtest && /tmp/navtest
```

## Layer B — QNX user-mode via QEMU (the main workhorse)

QNX 6.5 binaries (dynamic, interpreter `/usr/lib/ldqnx.so.2`) need a **built
QNX 6.5 runtime**, not the stock Linux glibc. Use
[luka-dev/qnx65-armv7-toolchain](https://github.com/luka-dev/qnx65-armv7-toolchain):

```sh
git clone https://github.com/luka-dev/qnx65-armv7-toolchain
cd qnx65-armv7-toolchain && ./host-scripts/qnx-run.sh build 8.5
# then re-register the binfmt handlers so .ESF/ELF/QNX binaries load:
./tools/install_binfmt.sh      # if provided; otherwise patch your binfmt_misc rules
```

Point `run_dmdt.sh` / `run_gal.sh` (already in this folder) at the toolchain's
`ldqnx.so.2` and the QNX libs it builds; the scripts here already carry the
interface (`ROOT/eso/bin/apps/{gal,dmdt}`) and only need the loader swapped:

```sh
ROOT=tests/emul/root  # stage real unit files here (git-ignored)
mkdir -p tests/emul/root/eso/bin/apps tests/emul/root/eso/lib
cp <your-unpacked-app.img>/eso/bin/apps/gal      tests/emul/root/eso/bin/apps/
cp <your-unpacked-app.img>/eso/bin/apps/dmdt     tests/emul/root/eso/bin/apps/
cp <your-unpacked-app.img>/eso/lib/libautoreceiver.so tests/emul/root/eso/lib/
cp <your-unpacked-app.img>/eso/lib/libairplay.so tests/emul/root/eso/lib/

sh tests/emul/run_dmdt.sh gs        # real `dmdt gs` → arbiter probe format
sh tests/emul/run_gal.sh --help     # real `gal` → registration path
```

When `run_dmdt.sh gs` produces real output, capture it as
`tests/emul/fixtures/dmdt_gs_<train>.txt` (firmware stays out of git) and
extend `tests/nav_translate_test.c` style host tests so the player's
`keep_map_stock_seen()` parser has a verified input string (e.g., does
`33` appear as a standalone word; how the stock context is labelled).

## What can be answered today vs later

| Question | Where | Layer |
|---|---|---|
| Does `gal` in this unit match a popular profile row? | `profile_check_test.sh` against the real `gal` | A |
| Does `0x8006/0x8007 → 0x8004/0x8005` translation parse the unit's bytes? | `nav_translate_test` | A |
| Does the arbiter's `dmdt gs` probe format match this unit? | `run_dmdt.sh gs` + a captured fixture | B |
| Will the hook bind all its symbol anchors to this unit's `gal` + `libautoreceiver.so`? | `tools/find_profile.py porting_X/gal porting_X/libautoreceiver.so TRAIN` (upstream) + the real files | A |
| Will a rebuild of `libcarplay_cluster.so` bind its trampolines to this unit's `libairplay.so`? | `carplay/` build + a stub with the real `libairplay.so` (Layer B later) | B |
| Will the parallel video OTA framing survive MOST sidebands without real MOST? | Layer C (research, not done here) | C |

## Layout

```
tests/emul/
├── README.md           this file
├── run_dmdt.sh          qemu-arm wrapper for the unit's dmdt binary
├── run_gal.sh           qemu-arm wrapper for the unit's gal binary (hook-aware)
├── root/                staged real firmware files; git-ignored
└── fixtures/            captured outputs (e.g. dmdt_gs output snippets), git-ignored
```

`.venv/` carries the Python deps used by tools/find_profile.py and the repo's
host tests (kaitaistruct, crcmod, pytest), pinned in `requirements.txt` at repo
root.
