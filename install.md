# Install this M.I.B. Addon

M.I.B. is the base toolbox — install it first (as noted in its own README and
your M.I.B. installation walkthrough, via metainfo2 updater on the car).

## What you need

- M.I.B. installed and running in GEM (V3.8.0+ recommended).
- Car: a VW MQB AID car on an upstream-supported MHI2 train — profile-verified example: Tiguan AD1 with the 9.2" AID10. Start with the **Status** screen: it reports which profile your unit matches.
- Cluster NOT patched with M.I.B.'s `CarPlay Maps VC` omonob payload — this
  Addon is Android Auto in VC only. Do NOT stack both.

## What goes on the SD card (statging)

Format a card FAT32, copy the **full M.I.B. tree** to it
(`Launcher-sda0.esd`, `esd/*`, `mod/*`, `apps/`, `patches/`, `metainfo2.txt`),
then add:

```
<M.I.B.-SD-card>/
└── mod/
    ├── carplay_maps_vc/          ← already in M.I.B., left untouched
    └── cluster_map_aa_greenmenu/ ← THIS Addon's payload (copy from this repo/mod/…)
        ├── enable_hook.sh  disable_hook.sh  collect_logs.sh
        ├── scripts/hook_status.sh  scripts/lib_*.sh  scripts/window_fix.sh
        ├── libgal_hook.so  stream-player  lib/libdmdt_flush.so  profile_check
        ├── thirdparty/NavActiveIgnore.jar  thirdparty/VCAndroidAuto.jar
        ├── lsd_jar.sh  turn_by_turn.sh
        ├── profiles.conf  gal_dualscreen.conf
        └── SHA256SUMS.txt  LICENSE
```

## How to add the screens to M.I.B.'s own launcher

Take `esd/Launcher-sda0.esd.append.md` from this repository, and paste the
screen block at the end of your M.I.B. SD card's `Launcher-sda0.esd` file
(UTF-8 without BOM, file line endings as M.I.B. ships them; the end of the
launcher file is where M.I.B.'s own GEM blocks stop). M.I.B. reads the
launcher straight from the SD card on every boot.

## Running in the car

Insert the SD card in **SD slot 1** and enter M.I.B.'s GEM (hold MENU →
Testmode). Open **Cluster Map — mib-cluster-map**; the Addon's 4 screens
drive the fork's own `enable_hook.sh` / `disable_hook.sh` / `hook_status.sh` /
`collect_logs.sh` from the fork's `mod/cluster_map_aa_greenmenu/` payload
folder.

Connect the phone to USB, run a map, and switch the cluster to map view.

## Uninstalling

Run the `Uninstall` screen. It reverses the fork's own install (`disable_hook.sh`)
and restores the stock `smartphone_integrator.json` + M.I.B.'s own routes.

## Troubleshooting

* `FAIL: mod/cluster_map_aa_greenmenu was not found on SD media.` — the payload
  folder wasn't copied to the SD card, or it's on the wrong drive.
* `PROFILE_MISMATCH_*` — your unit's `gal`/`libautoreceiver.so` fingerprints
  differ from the table in the fork's `profiles.conf`. Use the fork's
  own `tools/find_profile.py` to add a new row, or run the fork's
  `collect_logs.sh` and post the output on
  [MacsInSpace/mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map).
* `CLUSTERMAP_UPDATE_FIRMWARE_FIRST` — this train needs M.I.B.'s own extended
  binary first; M.I.B.'s own AIO patch handles that.

## Files the mod actually writes on the unit

Same as the fork's own installer — M.I.B. 's own screen is what invokes it,
not a separate launcher:

- `/mnt/app/eso/lib/gal_dualscreen/libgal_hook.so` (+ `gal_dualscreen.conf`)
- `/mnt/app/eso/lib/gal_dualscreen/libdmdt_flush.so`
- `/mnt/app/navigation/stream-player`
- `/mnt/system/etc/eso/production/smartphone_integrator.json` (preload entry only)
- `/mnt/app/eso/hmi/lsd/lsd.sh` (preload of `NavActiveIgnore.jar` listings)
