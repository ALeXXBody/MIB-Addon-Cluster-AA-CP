# M.I.B. Add-on — Cluster AA/CP

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-ffdd00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/ALeXXBody)


**Android Auto map on the Virtual Cockpit (digital instrument cluster)** on Volkswagen MQB-platform cars with the Harman MHI2 (MIB2.5 High) head unit — packaged as an **M.I.B. mod**.

**Install = copy & paste only. You never edit any file.** The mod ships with M.I.B.'s own documented hook (`mod/custom.sh`): one click in M.I.B.'s GEM installs everything; M.I.B.'s `Launcher-sda0.esd` is never touched.

> **STATUS — actively developed, not finished.** This add-on is a working
> experiment on real car hardware. It can have bugs; a version and the
> next can behave differently; perfect behaviour is not promised. New
> capabilities arrive because someone presses a switch and sends feedback —
> the car test round *is* the development loop. **Use in the car is at
> your own risk**: always keep a way back (the add-on's own **Uninstall**,
> `rescue_revert.sh`, and M.I.B.'s own firmware/backup paths), and send
> `diag.txt` (ClusterMap → *Save logs*) plus a cluster photo whenever
> something looks off — every report feeds the next build.
> The licence is GPL-3.0 and the project is unsupported software (no
> warranty at all — see `LICENSE`).


- Engine: [mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map) (fork of [chopinwong01 / mhi2-android-auto-video-vc](https://github.com/chopinwong01/mhi2-android-auto-video-vc)) — hooks the unit's `gal` process and drives the cluster over MOST150.
- Wrapper: **M.I.B. — More Incredible Bash** is the base toolbox; this repo only adds one payload folder + one `custom.sh`.

## The install in three steps (this is the whole flow)

1. **Download two things:** [M.I.B.](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash) (SD image/release) and this repository (green "Code" → ZIP).
2. **Copy & paste to an SD card** (FAT32):
   - unpack M.I.B. onto the card,
   - unpack this ZIP and copy its **`mod/` folder onto the card as well** — it merges next to M.I.B.'s own `mod/` folder (nothing in M.I.B. is touched or overwritten).
3. **In the car (SD slot 1): boot** with the card. If M.I.B. is not installed on the unit yet, do the M.I.B. install the usual way (metainfo2 → Updater). If it already is, nothing to do here.
4. **One click:** hold MENU → **Testmode** → GEM → **M.I.B. → Advanced Settings → “Run /mod/custom.sh from m.i.b. SD”**.
   That single run:
   - validates the screen file, then puts the mod's **`ClusterMap`** screen on the unit (the same mechanism M.I.B. itself uses for its own menu),
   - stages and **arms** the hook (the shipped payload carries the `HOOK_ARMED` marker), backing up the unit's stock player as `stream-player.aacluster-original`,
   - writes **one diagnostic file** (`diag.txt`, see below) whatever the outcome.
5. **Reboot the unit** (hold the power button ~10 s). Back in GEM you now have a new **top-level `ClusterMap` screen**: Status / Install / Make live / Uninstall / Keep-map / Verify / logs. The map is on the cluster.
6. **Use it:** plug your phone into USB, open Google Maps or Waze, switch the cluster to map view. Done.

### v0.5.0 in one paragraph

One zip, one GEM click. The menu entries are **M.I.B.-conformant bare
paths** (`greenmenu/gem/<name>.sh` - your GEM resolves the whole quoted
`value` as the script name, so entries never carry arguments), the screen
paths use the spelling your GEM executes (`/net/mmx/fs/sda0/...`), every
script name the menu can touch is existence-audited offline (48 tests),
and every press floors the console to the minimum (GEM 4.12st's console
re-entry bug renders "..." otherwise) while the FULL story of every run
goes into `diag.txt` on the card. The picture tune is pinned: full frame
on your car (`FULL_FRAME=1`, PAR 1.61, margins 0) and carried across
re-installs (`CLUSTERMAP_KEEP_SETTINGS=1` + the shipped defaults
snapshot). Use **short clicks**, one press then **Back**; evidence =
press Save logs and send `mod/cluster_aa/diag.txt`.

**Want it staged but not live?** Delete `mod/cluster_aa/HOOK_ARMED` from the card before step 4. The run then touches nothing live, and the GEM's **“2b. Make the map LIVE”** entry arms it later — no card edit, no PC.

## One file to send if anything looks wrong

Every install/uninstall/settings run writes a single diagnostic file and
prints its name on the GEM screen:

- `/tmp/clustermap_diag/diag.txt` on the unit (RAM, always, authoritative),
- copied **and verified** onto the card at `mod/cluster_aa/diag.txt`, through
  the first card view spelling that actually accepts a write.

**The console tells the truth about the card copy.** Since v0.4.22 every run
ends with `card copy: <path>` when the copy landed, or
`card copy: NOT WRITTEN - the card is read-only to the unit` when it did not
— plus the tuning facts right there on the screen, so a photo of the GEM
screen is enough to fine-tune even with no card copy. (v0.4.21 failed that
copy silently, which is why a card could show no diag.txt at all while the
map worked.)

Send that one file (plus a cluster photo if the picture is the issue). It
carries the unit/train facts, the card and unit views, the arm state, the
installed map settings (window / DPI / insets / aspect / zoom / full-frame),
the hook log tail and the full run log — enough to diagnose a failure and to
tune the picture without another round-trip. `diag.txt.prev` keeps one
previous bundle.

The card is **never written during normal operation** — only that single
best-effort copy. See the troubleshooting note below for why.

## Card layout after step 2 (yours exactly)

```
M.I.B. SD card root/
├── Launcher-sda0.esd          ← M.I.B.'s own, UNTOUCHED
├── metainfo2.txt, apps/, patches/, esd/, config/, …
├── … (M.I.B.'s own mod/ folder, incl. its mod/carplay_maps_vc/)
└── mod/                       ← merged: M.I.B.'s mods + this Add-on's
    ├── custom.sh                      ← this repo (the one-click hook)
    └── cluster_aa/                    ← this repo (the mod payload)
        ├── greenmenu/cluster-map.esd  ← the GEM screen that gets copied to the unit
        ├── greenmenu/{install,status,uninstall,verify,keep_map,…}.sh
        ├── enable_hook.sh  disable_hook.sh  collect_logs.sh
        ├── libgal_hook.so  stream-player  lib/libdmdt_flush.so  profile_check
        ├── profiles.conf  gal_dualscreen.conf  lsd_jar.sh  turn_by_turn.sh
        └── thirdparty/{NavActiveIgnore.jar, VCAndroidAuto.jar} + SHA256SUMS
```

Older releases used `mod/cluster_map_aa_greenmenu/`; every locator still
finds it (it is preferred second), so an existing card keeps working —
delete the old folder once `mod/cluster_aa/` is on the card.

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
- **Do not stack this with M.I.B.'s own “CarPlay Maps VC” payload** on the same unit: they both install a cluster-map hook and conflict. Pick one protocol path per unit (this Add-on is the Android Auto path).
- **M.I.B. option 7 (“CarPlay & Android Auto activation”) should be applied first** — the mod does not write persistence bits; it only installs files.
- `mod/custom.sh` is M.I.B.'s documented user hook. If you also use another mod that ships `mod/custom.sh`, append its commands at the “ADDON CODE” marker of this file instead of overwriting it.
- Engine support follows the upstream profile table (`MHI2_ER_*` / `MHI2_US_*`); the complete chain is car-verified on a **Tiguan AD1, `MHI2_ER_VWG13_P4521`, AID10** — see `docs/car-test-notes.md`.

## Switches and persistence

Sharper map, Keep map and Zoom change the **unit's installed settings**, not your card. They survive reboots (Zoom's live file applies within seconds of clicking). A fresh **Install from the card resets them** — after a re-install re-click your preferred value; see `install.md` for the details.

## Troubleshooting — the card and “Read-only file system”

**Fixed for good in v0.4.20: the add-on no longer writes the card during
normal operation.** Backups, logs, staging and probes all live on the unit's
RAM (`/tmp/clustermap_unit`, `/tmp/gal_dualscreen.log`); the persistent
recovery copy that Uninstall needs is kept beside the unit's supervisor
config. This matters because our own earlier writes to the FAT card set its
dirty bit, and QNX then mounted the card **read-only on the next boot** —
which is what produced every “the SD card is read-only” report. The add-on
was blaming the card for its own writes.

If a card still mounts read-only on the unit (for example one written by an
older release), clear it once on a PC and it is done:

1. Run `chkdsk /f X:` on the card (Windows) — clears the volume-dirty flag.
2. Make sure the card is **FAT32** (exFAT/NTFS cards mount read-only on the unit).
3. Check the **LOCK slider** on the microSD→SD adapter is up/unlocked.

Old logs written by an older release are safe to delete: `mod/cluster_map_aa_greenmenu/logs/`,
`mod/cluster_map_aa_greenmenu/backups/`, `mod/cluster_map_aa_greenmenu/last_install_paths.txt`.

## Troubleshooting — `CLUSTERMAP_INSTALL_FAILED`

The console shows the outcome in a few lines; the full reason is in the
diagnostic file named on screen (see above). Send that file.

## Android Auto capabilities research

What the AA protocol can and cannot do for the cluster — with the official
knobs our engine rides on — is documented in
[`docs/android-auto-research.md`](docs/android-auto-research.md), including
the ranked next-feature list.

## Related projects

The broader research around this engine is surveyed in
[`docs/related-projects.md`](docs/related-projects.md) — including the
car-proven finding that steering-wheel zoom IS possible on this Harman MHI2
family via the HMI's DSI tracer (proposed here as an opt-in
`CLUSTERMAP_WHEEL_ZOOM`).

## Project ledger

Everything we know for certain — engine facts, debugging signatures, engine
decisions, waits — lives in the project [`LEDGER.md`](LEDGER.md). Read it
before touching anything; update it when you learn something new.

## Support

<div align="center">

### ☕ [Buy Me A Coffee — ALeXXBody](https://buymeacoffee.com/alexxbody)

*All support goes into hardware parts and tokens for building more free tools for the community.*

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-alexxbody-FFDD00?logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/alexxbody)

</div>

## Licence

Same upstream licence: GPL-3.0. See `LICENSE` and the per-file licence notes (`thirdparty/*.LICENSE`).


## Support this project

If this mod helps you with your Virtual Cockpit, consider buying me a coffee:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-ffdd00?style=flat&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/ALeXXBody)
