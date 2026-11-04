# M.I.B. Addon — Cluster AA/CP

**Android Auto & CarPlay map on the Virtual Cockpit** (VW Tiguan AD1 / Golf 7.5 / Passat B8 / AID10 & AID12.3, Harman MHI2 · MIB2.5 High) — packaged as an **M.I.B. mod**.

**M.I.B. must already be installed on the unit.** This is *not* a standalone installer and *not* an alternative to M.I.B. — it is an add-on that runs from M.I.B.'s own GEM screens, on M.I.B.'s SD card, using M.I.B.'s own conventions.

```
Main → M.I.B. → Cluster AA/CP — Tiguan fork
                  ├── 1. Status of the installed hook
                  ├── 2. Install the AA map on the cluster
                  ├── 3. Uninstall / restore stock gal
                  ├── 4. Save fork logs to SD
                  └── (M.I.B. itself already handles AA + CarPlay coding
                       via option 7 and CarPlay Maps VC via option AIO)
```

## Repo layout

```
MIB-Addon-Cluster-AA-CP/
├── README.md                                    ← this file
├── install.md                                   ← detailed install / troubleshooting
├── install.sh                                   ← host-side helper (Linux/macOS): stages the SD card
├── CHANGELOG.md
├── LICENSE                                      ← GPL-3.0 (same as M.I.B. / upstream)
├── docs/                                        ← provenance, the Tiguan doc, compatibility matrix
│   ├── Tiguan.md                                  (concrete Tiguan AD1 notes)
│   ├── FORK.md                                    (fork identity, licence)
│   └── mib-integration.md                         (M.I.B. ↔ fork feature matrix)
├── esd/                                         ← what you splice on M.I.B.'s launcher
│   ├── Launcher-sda0.esd.append.md               ← the 4 new GEM screens to paste into M.I.B.'s launcher
│   └── scripts/
│       ├── cm_aa_status.sh                        ← GEM wrapper #1 (runs fork's hook_status.sh)
│       ├── cm_aa_install.sh                       ← GEM wrapper #2 (runs fork's enable_hook.sh)
│       ├── cm_aa_uninstall.sh                     ← GEM wrapper #3 (runs fork's disable_hook.sh)
│       └── cm_aa_collect.sh                       ← GEM wrapper #4 (runs fork's collect_logs.sh)
├── mod/cluster_map_aa_greenmenu/                ← what lives on the SD card at mod/…
│   └── (the fork's actual payload — see below)
└── patches/                                     ← reserved for per-train IFS patches (empty by default)
```

## `mod/cluster_map_aa_greenmenu/` — the fork payload on the SD card

This is the *fork's own per-unit payload*, packaged as an M.I.B. "mod" so it can be driven from M.I.B.'s GEM screens. Follow the tree exactly:

| File | Purpose | Shipped in git |
|---|---|---|
| `scripts/enable_hook.sh` | install the AA→VC hook | ✅ |
| `scripts/disable_hook.sh` | uninstall | ✅ |
| `scripts/hook_status.sh` | status | ✅ |
| `scripts/collect_logs.sh` | log collection | ✅ |
| `scripts/lib_*.sh`, `scripts/lsd_jar.sh` | shared helpers | ✅ |
| `scripts/full_frame_on.sh`, `…off.sh`, `window_fix.sh`, `turn_by_turn.sh`, `experiments/zoom_test.sh` | GEM / zoom helpers | ✅ |
| `scripts/gal_dualscreen.conf` | the fork's `auto` profile | ✅ |
| `config/profiles.conf` | per-train profile table (P4521 / P4521_1 / K4525 / P4174 / P3662 / AU37x / SKG13 / SEG11 …) | ✅ |
| `config/framework.json` | the `dmdt` probe target layout the arbiter reads | ✅ (stock unit copy) |
| `thirdparty/NavActiveIgnore.jar`, `thirdparty/VCAndroidAuto.jar` | the forge's Java patches | ✅ (MIT per upstream) |
| `greenmenu/*.sh`, `greenmenu/cluster-map.esd` | the fork's own GEM screens (optional alternative to M.I.B.'s; not installed here) | ✅ |
| **`binaries/libgal_hook.so`** | **REQUIRED** — the AA hook | ❌ — you build it once |
| **`binaries/stream-player`** | **REQUIRED** — the AA→cluster player | ❌ — you build it once |
| `binaries/libdmdt_flush.so` | optional probe helper | ❌ |
| `binaries/dmdtgo.c`, `binaries/rundmdt` | AA map zoom helper (source + QNX wrapper) | ✅ source |

The three `.so` / `stream-player` binaries are **per-unit builds**: the fork compiles them with the unit's own `gal` + `libautoreceiver.so` fingerprints (matched per train via `tools/find_profile.py`). They never live in git — build once, drop them in the folder, and each unit recalculates its own `verify_manifest.txt` at install time via our `swdl/update_run.sh`.

## Install (concrete, from start to finish)

**Note:** no build needed by the owner. Copy the release from
[MacsInSpace/mib-cluster-map v1.1.0](https://github.com/MacsInSpace/mib-cluster-map/releases/tag/v1.1.0)
directly into this repo's `mod/cluster_map_aa_greenmenu/` (the Tiguan's
`libgal_hook.so`, `stream-player`, `libdmdt_flush.so` are already there, uploaded
from upstream v1.1.0 for convenience, since this mod specifically targets
Tiguan AD1 / AID10 / MIB2.5 High).  If you want to build your own,
`build_local.sh` in the upstream tree does it; but it's not needed.

**Step 1 — make the M.I.B. SD card.** Format a 2–32 GB card FAT32 and copy the full M.I.B. tree to it (your `Launcher-sda0.esd`, `esd/*`, `mod/*`, `apps/`, `patches/`, `metainfo2.txt`). Run M.I.B.'s own launcher to trigger the main M.I.B. install (`Launcher-sda0.esd` → *PATCH NOW*), follow M.I.B.'s own instructions for your unit.

**Step 2 — copy this mod's payload to that same SD card.** Download the zip of a tagged release on your fork and copy:

* `mod/cluster_map_aa_greenmenu/` ➜ to `mod/cluster_map_aa_greenmenu/` on the SD card
* `esd/scripts/cm_aa_*.sh` ➜ to `esd/scripts/` on the SD card
* `esd/Launcher-sda0.esd.append.md` ➜ read it, and paste the block at the *bottom of your existing* `Launcher-sda0.esd` on the SD card.

Or run the repo's host helper directly from Linux/macOS:

```sh
./install.sh /path/to/MIB-SD-card
```

**Step 3 — install the unit's per-unit binaries.** Compile the fork yourself with

```sh
git clone https://github.com/ALeXXBody/mib-cluster-map-tiguan.git
cd mib-cluster-map-tiguan && ./the upstream release zip (mib-cluster-map_v1.1.0.zip)
# OR use tools/find_profile.py to add your train, then build.
```

…then copy the generated `libgal_hook.so`, `stream-player`, `libdmdt_flush.so` into `mod/cluster_map_aa_greenmenu/binaries/` on the SD card.

**Step 4 — put the card into SD slot 1** of the unit and boot to M.I.B.'s GEM.
M.I.B.'s own AIO patch (`PATCH NOW`) already:
* activates Android Auto, CarPlay & MirrorLink coding in persistence (`0xC0020054` bits 7.7 / 8.0 / 8.5),
* adds `NavActiveIgnore.jar` if needed,
* enables the Green Engineering Menu.

**Step 5 — from M.I.B.'s GEM, open the new screen `Main → M.I.B. → Cluster AA/CP — Tiguan fork` and use the 4 screens:**

| GEM screen | The fork's script it runs | What it does |
|---|---|---|
| Status | `hook_status.sh` | tells you if the hook is loaded, whether the phone is connected |
| Install | `enable_hook.sh` | writes `libgal_hook.so` + `stream-player` + `smartphone_integrator.json` preload entry + the fork's `gal_dualscreen.conf` |
| Uninstall | `disable_hook.sh` | restores stock `smartphone_integrator.json` and removes the fork's `lib/…` files |
| Save fork logs | `collect_logs.sh` | copies `hook_status` + `dmdt` state to the SD card for issue reports |

Reload, restart the unit, plug the phone in and switch the cluster to map view.

**Step 6 (optional) — CarPlay Maps VC on the cluster.** If you also want CarPlay maps, M.I.B.'s own `mod/carplay_maps_vc/omonob` payload (bundled in M.I.B. upstream since V3.7.2, 2026-10-07) will install CarPlay's cluster map. Do **not** install that payload alongside this one — they'd write to the same install paths (`carplaymaps/`, `CarPlayClusterControls*.jar`, `altscreen-most-bridge`) and conflict.
Choose: Android Auto (this mod) **or** CarPlay (M.I.B.'s bundled payload). Not both.

## Troubleshooting

The GEM screens produce logs on the SD card under `mod/cluster_map_aa_greenmenu/logs/`, hook side and player side — `hook_status.sh` is the first stop, and `update_result.txt` documents each install run. Upstream docs live in the fork's own [`docs/Install.md`](https://github.com/ALeXXBody/mib-cluster-map-tiguan/blob/tiguan-fork/docs/Install.md) and [`docs/Development.md`](https://github.com/ALeXXBody/mib-cluster-map-tiguan/blob/tiguan-fork/docs/Development.md).

## Licence and sources

* This fork: GPL-3.0, same as [upstream mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map) (MacsInSpace, GPL-3.0-only) and [M.I.B.](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash) (GPL-2.0). See `LICENSE`.
* Full provenance for the underlying engine in `docs/FORK.md` and in the upstream README — chopinwong01, andrewleech, OneB1t, jilleb, harman-f, omonob, AMDFX60, kkrvch, kamgurgul, luka-dev.
* Fork repository (mainline work): [`ALeXXBody/mib-cluster-map-tiguan`](https://github.com/ALeXXBody/mib-cluster-map-tiguan)

## Compatibility — at a glance

| Feature on this unit | M.I.B. alone | This addon | Combined |
|---|---|---|---|
| **Android Auto map in the Virtual Cockpit** | ❌ | ✅ | ✅ (this mod is the only sender) |
| **CarPlay map in the Virtual Cockpit** | ✅ (M.I.B.'s bundled omonob payload) | ✅ | ⚠️ pick one sender — not both |
| AA / CarPlay / MirrorLink coding (`0xC0020054` 7.7 / 8.0 / 8.5) | ✅ | ✅ | ✅ idempotent |
| IFS-ROOT-Stage2 patch (CP / FEC / EL) | ✅ (M.I.B. flash option) | ❌ (fork doesn't patch IFS) | ✅ complementary |
| NavActiveIgnore | ✅ toolbox knows it | ✅ same jar name | ✅ |
| GEM screens | M.I.B.'s own set | This mod's one top-level section | ✅ separate |
| VIM / sport display / ambient | ✅ M.I.B.-only | ❌ | ✅ |
| MHI2Q (Qualcomm) | ⚠️ M.I.B. supports it; this mod does not | ❌ for MHI2Q use [`kamgurgul/mib2q-carplay`](https://github.com/kamgurgul/mib2q-carplay) | — |
| MIB2 Standard (`MST2_*`) | ❌ | ❌ | — |

## Thanks

See `docs/FORK.md` and the upstream READMEs for the full attribution list — this mod only *packages* and exposes the open-source work of:
[Mr-MIBonk & the M.I.B. team](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash) (base toolbox + GEM framework),
[MacsInSpace / mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map) (the upstream code this fork is from),
[chopinwong01 / mhi2-android-auto-video-vc](https://github.com/chopinwong01/mhi2-android-auto-video-vc),
[andrewleech / VcMOSTRenderMqb](https://github.com/andrewleech/VcMOSTRenderMqb) + MIB SDK,
[harman-f / mhi2_altscreen_carplay](https://github.com/harman-f/mhi2_altscreen_carplay),
[jilleb / mib2-toolbox](https://github.com/jilleb/mib2-toolbox),
[olli991 / mib-std2-pq-zr-toolbox](https://github.com/olli991/mib-std2-pq-zr-toolbox),
[adi961 / mib2-android-auto-vc](https://github.com/adi961/mib2-android-auto-vc),
[kkrvch / mib-std2-kombibridge](https://github.com/kkrvch/mib-std2-kombibridge),
[kamgurgul / mib2q-carplay](https://github.com/kamgurgul/mib2q-carplay),
[luka-dev / mib2q-carplay-rgi](https://github.com/luka-dev/mib2q-carplay-rgi)
and [omonob / MHI2-Carplay-Maps](https://github.com/omonob/MHI2-Carplay-Maps).

Not affiliated with Volkswagen AG, Harman International, Google LLC, Apple Inc. or Škoda Auto. All trademarks belong to their owners.
