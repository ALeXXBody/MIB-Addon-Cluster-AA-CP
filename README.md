# M.I.B. Addon — Cluster AA/CP

**Android Auto map on the Virtual Cockpit** on VW Tiguan AD1 / Passat B8 / Golf 7.5 / AID10 & AID12.3 with the Harman MHI2 (MIB2.5 High) head unit — packaged as an **M.I.B. mod** that runs inside M.I.B.'s own GEM screens.

**This is an add-on for [M.I.B. — More Incredible Bash](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash).** M.I.B. is the base toolbox (installed by you, on the car, via metainfo2/Updater); this repository piggy-backs on M.I.B.'s own GEM to install one extra feature: **Google Maps / Waze on the instrument cluster, driven by an Android phone running Android Auto**.

The mod *doesn't* add its own installer screens, duplicate M.I.B.'s GEM, or write its own persistence bits. Everything is driven from M.I.B.'s GEM screen, and M.I.B. is left untouched.

## The screen inside M.I.B.'s GEM

```
Main → Cluster AA/CP — Tiguan fork (mib-cluster-map)
        1. status        — is the hook there? is the phone connected?
        2. install       — runs the fork's enable_hook.sh
        3. uninstall     — restores the stock gal
        4. save logs     — saves fork logs to the SD card
```

Each screen calls the fork's own scripts (`enable_hook.sh`, `disable_hook.sh`, `hook_status.sh`, `collect_logs.sh`) from the fork's `mod/cluster_map_aa_greenmenu/` folder on the M.I.B. SD card. Nothing jumps to M.I.B.'s own install area.

## Compatibility at a glance

| Feature | M.I.B. alone | this Addon |
|---|---|---|
| **Android Auto map in the instrument cluster** | ❌ | ✅ (this Addon) |
| **CarPlay map in the instrument cluster** | ✅ (M.I.B.'s bundled `carplay_maps_vc/omonob` payload) | ❌ |
| IFS-ROOT stage-2 patch / CP / FEC / EL | ✅ (M.I.B. does it) | ❌ |
| Persistence bit for AA / CarPlay coding | ✅ | ✅ (same bit address `0xC0020054`) |
| GEM screens | M.I.B.'s own | one extra section, via `esd/Launcher-sda0.esd.append.md` |
| NavActiveIgnore | ✅ shipped by M.I.B.'s own toolbox | ✅ (same jar) |
| VIM / sport display / ambient | ✅ M.I.B.-only | ❌ |
| MHI2Q (Qualcomm) | ✅ M.I.B. supports it | ❌ use [kamgurgul/mib2q-carplay](https://github.com/kamgurgul/mib2q-carplay) |
| MIB2 Standard (`MST2_*`) | ❌ | ❌ |

## How to install (concrete)

This is the correct order — one re-used M.I.B. install, one mod on top, no parallel installers:

1. **Make the M.I.B. SD card.** Format a card FAT32, copy the full M.I.B. tree to it (`Launcher-sda0.esd`, `esd/*`, `mod/*`, `apps/`, `patches/`, `metainfo2.txt`) and run M.I.B.'s own *AIO Patch* flow on the car as usual. After M.I.B.'s own launch is done and the *Green Engineering Menu is on* (which M.I.B. does by default), this mod is considered *installed but off* — even after the car reboots.
2. **Copy this Addon's files to the SD card.** Pull this repository's `mod/` and `esd/` folders onto your M.I.B. SD card root:
   <!-- the fork's "mod/cluster_map_aa_greenmenu/" and the M.I.B. GEM script -->
   ```sh
   <M.I.B.-SD-card>/
   ├── Launcher-sda0.esd                       ← M.I.B.'s own launcher, M.I.B. handles
   ├── esd/scripts/cm_aa_*.sh                   ← THIS REPO's 4 GEM add-on scripts
   ├── mod/
   │   ├── carplay_maps_vc/                    ← M.I.B.'s bundled CarPlay Maps VC (OWN)
   │       └── cluster_map_aa_greenmenu/           ← this Addon's AA→VC payload
   │           ├── enable_hook.sh  disable_hook.sh  collect_logs.sh
   │           ├── scripts/hook_status.sh  scripts/lib_*.sh  scripts/window_fix.sh
   │           ├── lsd_jar.sh  turn_by_turn.sh
   │           ├── profiles.conf  gal_dualscreen.conf
   │           ├── libgal_hook.so  stream-player  lib/libdmdt_flush.so
   │           ├── profile_check
   │           ├── thirdparty/NavActiveIgnore.jar  thirdparty/VCAndroidAuto.jar
   │           └── SHA256SUMS.txt
   ├── patches/ (if M.I.B. has it)
   ```
3. **Splice the 4 GEM screens into M.I.B.'s existing Launcher-sda0.esd.** Take the block from `esd/Launcher-sda0.esd.append.md` at the bottom of this repo and paste it into your M.I.B. SD card's `Launcher-sda0.esd` file (or use a text editor on Windows — file is UTF-8 without BOM; the end of the file is the correct place, and that's not a fork-specific convention, just a text edit).
4. **Boot the car into M.I.B.'s Green Engineering Menu** (hold MENU → Testmode → M.I.B.). The new screens are live because M.I.B.'s launcher reads `Launcher-sda0.esd` from the SD card on every boot.
5. **Use the Fork's GEM screens.** M.I.B. stays the base toolbox; the Addon's 4 screens drive the fork's own payload and route the phone's AA map onto the instrument cluster via the fork's `stream-player` / `libgal_hook.so` engine.

The Addon is fully self-contained: no fork's own GEM screens, no metainfo2 installer, no extra launcher to install — M.I.B. handles all installation; the mod's *files on the SD card* are what make the fork run inside M.I.B.'s own GEM.

## What normally goes on the unit during install

This is what M.I.B. already does on every AIO Patch install; this Addon **only adds one extra GEM screen entry** into M.I.B.'s own launcher:

- `/mnt/app/eso/lib/gal_dualscreen/libgal_hook.so` — fork hook (injected into `gal`)
- `/mnt/app/eso/lib/gal_dualscreen/gal_dualscreen.conf` — the fork's profile / DPI / insets
- `/mnt/app/navigation/stream-player` — fork player (dual-AA display)
- `/mnt/app/eso/hmi/engdefs/cluster-map.esd` — *fork's* GEM screen (only installed if you also run M.I.B.'s own HUD screen)
- `/mnt/app/eso/hmi/lsd/lsd.sh` — fork `dmdtgo` injection

These are written by the fork's own `enable_hook.sh` (running *inside* M.I.B.'s shell once you've called the Addon's "install" screen from M.I.B. GEM).

## Licence

Same as M.I.B. and the fork: GPL-3.0. See `LICENSE`.

## Sources / credits

- Base toolbox: [Mr-MIBonk / M.I.B. — More Incredible Bash](https://github.com/Mr-MIBonk/M.I.B._More-Incredible-Bash)
- Fork engine: [chopinwong01 / mhi2-android-auto-video-vc](https://github.com/chopinwong01/mhi2-android-auto-video-vc); packaged by [MacsInSpace / mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map); maintained in this Tiguan fork at [ALeXXBody / mib-cluster-map-tiguan](https://github.com/ALeXXBody/mib-cluster-map-tiguan)
- Cluster render path: [andrewleech / VcMOSTRenderMqb](https://github.com/andrewleech/VcMOSTRenderMqb) + MIB SDK
- CarPlay: [harman-f / mhi2_altscreen_carplay](https://github.com/harman-f/mhi2_altscreen_carplay), [aberbic / Audi-MHI2-…-Altscreen](https://github.com/aberbic/Audi-MHI2-Virtual-Cockpit-Altscreen-CarPlay-AndroidAuto)
- Turn arrows: [adi961 / mib2-android-auto-vc](https://github.com/adi961/mib2-android-auto-vc); message parsing from [kkrvch / mib-std2-kombibridge](https://github.com/kkrvch/mib-std2-kombibridge)
- MHI2Q (Qualcomm) peer project: [kamgurgul / mib2q-carplay](https://github.com/kamgurgul/mib2q-carplay); [luka-dev / mib2q-carplay-rgi](https://github.com/luka-dev/mib2q-carplay-rgi)
- Some upstream README from [Feserich / mib2std-zr-firmware-upgrade](https://github.com/Feserich/mib2std-zr-firmware-upgrade)

Not affiliated with Volkswagen AG, Harman International, Google LLC, Apple Inc. or Škoda Auto. All trademarks belong to their owners.
