# M.I.B. Addon — Cluster AA/CP

**Android Auto map on the Virtual Cockpit (digital instrument cluster)** on Volkswagen MQB-platform cars with the Harman MHI2 (MIB2.5 High) head unit — packaged as an **M.I.B. mod**.

**Install = copy & paste only. You never edit any file.** The mod ships with M.I.B.'s own documented hook (`mod/custom.sh`): one click in M.I.B.'s GEM installs everything; M.I.B.'s `Launcher-sda0.esd` is never touched.

- Engine: [mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map) (fork of [chopinwong01 / mhi2-android-auto-video-vc](https://github.com/chopinwong01/mhi2-android-auto-video-vc)) — hooks the unit's `gal` process and drives the cluster over MOST150.
- Wrapper: **M.I.B. — More Incredible Bash** is the base toolbox; this repo only adds one payload folder + one `custom.sh`.

## The owner flow (this is the whole install)

1. **Download two things:** [M.I.B.](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash) (SD image/release) and this repository (green "Code" → ZIP).
2. **Copy & paste to an SD card** (FAT32):
   - unpack M.I.B. onto the card,
   - unpack this ZIP and copy its **`mod/` folder onto the card as well** — it merges next to M.I.B.'s own `mod/` folder (nothing in M.I.B. is touched or overwritten).
3. **In the car (SD slot 1): boot** with the card. If M.I.B. is not installed on the unit yet, do the M.I.B. install the usual way (metainfo2 → Updater). If it already is, nothing to do here.
4. **One click:** hold MENU → **Testmode** → GEM → **M.I.B. → Advanced Settings → “Run /mod/custom.sh from m.i.b. SD”**.
   This:
   - puts the mod's **`ClusterMap`** screen on the unit (one file into the GEM screen folder, the same mechanism M.I.B. itself uses for its own menu),
   - then runs the mod's installer straight away (status/profile check → hook + player install).
5. **Reboot the unit** (hold the power button ~10 s). Back in GEM you now have a new **top-level `ClusterMap` screen**: Status / Install / Uninstall / Keep-map / Verify / logs.
6. **Use it:** plug your phone into USB, open Google Maps or Waze, switch the cluster to map view. Done.

## Card layout after step 2 (yours exactly)

```
M.I.B. SD card root/
├── Launcher-sda0.esd          ← M.I.B.'s own, UNTOUCHED
├── metainfo2.txt, apps/, patches/, esd/, config/, …
├── … (M.I.B.'s own mod/ folder, incl. its mod/carplay_maps_vc/)
└── mod/                       ← merged: M.I.B.'s mods + this Addon's
    ├── custom.sh                      ← this repo (the one-click hook)
    └── cluster_map_aa_greenmenu/      ← this repo (the mod payload)
        ├── greenmenu/cluster-map.esd  ← the GEM screen that gets copied to the unit
        ├── greenmenu/{install,status,uninstall,verify,keep_map,…}.sh
        ├── enable_hook.sh  disable_hook.sh  collect_logs.sh
        ├── libgal_hook.so  stream-player  lib/libdmdt_flush.so  profile_check
        ├── profiles.conf  gal_dualscreen.conf  lsd_jar.sh  turn_by_turn.sh
        └── thirdparty/{NavActiveIgnore.jar, VCAndroidAuto.jar} + SHA256SUMS
```

## What it looks like

> Drop your own driving screenshots into `docs/photos/` (names used below), then
> this section shows them on GitHub; see `docs/photos/README.md` for the list.

| Full-map view | Classic dials view |
|---|---|
| `![map](docs/photos/cluster-map-full-frame.jpg)` | `![dials](docs/photos/cluster-map-classic-view.jpg)` |

Google Maps draws its navigation card *inside* the phone's video, so the green
turn card you see in the map is Google-side (not the unit's): it cannot be
moved or shrunk from the unit. See the card chapter below for what actually
changes it.

## Notes & conflicts

- **MHI2Q (Qualcomm) and MIB2 Standard are not supported** — the profile table (`profiles.conf`) gates any install and refuses trains it does not know, so a wrong unit cannot be bricked by this mod.
- **Do not stack this with M.I.B.'s own “CarPlay Maps VC” payload** on the same unit: they both install a cluster-map hook and conflict. Pick one protocol path per unit (this Addon is the Android Auto path).
- **M.I.B. option 7 (“CarPlay & Android Auto activation”) should be applied first** — the mod does not write persistence bits; it only installs files.
- `mod/custom.sh` is M.I.B.'s documented user hook. If you also use another mod that ships `mod/custom.sh`, append its commands at the “ADDON CODE” marker of this file instead of overwriting it.
- Engine support follows the upstream profile table (`MHI2_ER_*` / `MHI2_US_*`); the complete chain is car-verified on a **Tiguan AD1, `MHI2_ER_VWG13_P4521`, AID10** — see `docs/car-test-notes.md`.

## Troubleshooting — “Read-only file system” / `CLUSTERMAP_INSTALL_FAILED`

The installer keeps `backups/` and `logs/` on the SD card, so the card must be writable to the unit. The three usual causes, in order:

1. **The LOCK slider on the SD adapter is on.** MicroSD→SD adapters are shipped with it slid down (locked). Move it to the up/unlocked position, re-insert, run the screen again.
2. **The card is not FAT32.** exFAT/NTFS cards normally mount read-only on the unit. Reformat FAT32 and re-copy M.I.B. + this repo's `mod/`.
3. **The card has the volume-dirty flag set** (typically after it was pulled while the unit was writing). The unit then mounts it read-only until the flag is cleared: run `chkdsk /f X:` (Windows) on the card from a PC, re-insert, run again.

The Green Engineering Menu console now says explicitly when the card is read-only, with these same three steps.

## Licence

Same upstream licence: GPL-3.0. See `LICENSE` and the per-file licence notes (`thirdparty/*.LICENSE`).
