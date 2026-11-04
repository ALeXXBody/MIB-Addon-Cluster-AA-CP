# Install this M.I.B. mod

## Pre-req
- M.I.B. installed and GEM running (V3.8.0+ recommended).
- Car: Tiguan AD1 AID10-compatible, or Golf / Passat B8 family with AID.
- Cluster firmware NOT patched with M.I.B.'s `CarPlay Maps VC` omonob payload — this mod is Android Auto only; do NOT stack both.

## What the mod ships (car-tested upstream mib-cluster-map v1.1.0 for the Tiguan / VWG13 family)

Included in **this mod's mod/cluster_map_aa_greenmenu/**, ready to copy onto an
M.I.B. SD card:

| File | Purpose |
|---|---|
| `libgal_hook.so` | The fork's AA → VC hook itself (injects the second screen into the unit's own `gal`) |
| `stream-player` | The player that decodes the phone's cluster stream and draws it through the display manager |
| `lib/libdmdt_flush.so` | Interposer for `dmdt`, so the fork can read the Kombi map size |
| **`profile_check`** | ARM ELF — *this is what the installer uses to fingerprint your unit's `gal` before it decides whether the profile matches*; upstream v1.1.0 does NOT ship this (only `tools/profile_check.c`) and the install silently skips the gal check without it |
| `NavActiveIgnore.jar`, `VCAndroidAuto.jar` | Java patches, from jilleb / adi961 (MIT) |
| `config/profiles.conf` | Per-train profile table (P4521 / K4525 / P4174 / P3662 / AU37x / SKG13 / SEG11 / VWG11 / P3301) |
| `config/framework.json` | The IFS `framework.json` the fork's arbiter matches on |
| `enable_hook.sh` / `disable_hook.sh` / `scripts/hook_status.sh` / `collect_logs.sh` | The fork's own install / uninstall / status / log scripts |
| `scripts/lib_*.sh`, `scripts/lsd_jar.sh`, `scripts/full_frame.sh`, `scripts/window_fix.sh`, `scripts/turn_by_turn.sh`, `scripts/experiments/zoom_test.sh` | Helpers |
| `GEM/*.sh`, `GEM/cluster-map.esd` | The fork's own GEM screens — *optional on M.I.B.'s setup; use M.I.B.'s own launcher instead* |
| `LICENSE`, `docs/{README.md,Install.md}` | Fork GPL-3.0, matching the package contents |

## SD-card staging
1. Format a card FAT32, copy your existing M.I.B. root to it (keep ALL of M.I.B.: `Launcher-sda0.esd`, `esd/*`, `mod/*`, `apps/`, `patches/`, `metainfo2.txt`).
2. Copy **this mod's** `mod/cluster_map_aa_greenmenu/` to the SD card (same folder layout).
3. Copy the 4 M.I.B. screen wrappers (`esd/scripts/cm_aa_*.sh`) into the M.I.B. SD card's `esd/scripts/`.
4. Open the existing `Launcher-sda0.esd` and paste the screen block from `esd/Launcher-sda0.esd.append.md` at the bottom of the file.

## Run from M.I.B.'s GEM
Put the card into **SD slot 1**, enter M.I.B. GEM (hold MENU > Testmode), then use the new screens:
1. `Cluster Map AA/CP — Tiguan fork`: **Status** (uses the fork's `hook_status.sh` + `profiles.conf` probe)
2. **Install** (uses `enable_hook.sh`): needs M.I.B.'s own flashing image not to be installed at the same time.
3. **Uninstall** (reverse).
4. **Save fork logs to SD**.

All four run the fork's own scripts from the unit's SD card mount at
`/net/mmx/fs/sda0/mod/cluster_map_aa_greenmenu/…`; the fork's ownership and
profiles stay in the fork's own `profiles.conf`.

## Troubleshooting
- `FAIL: MMX_FILESYSTEM_NOT_FOUND` — the script could not find `/net/mmx/ifs/lsd.jxe`; the unit must be MHI2 (MIB2 High, Harman), not MIB2 Stard (`MST2_*`) or MIB1.
- `PROFILE_MISMATCH_*` — this unit's `gal` is *not* in `config/profiles.conf`. Use the upstream fork's `tools/find_profile.py` to add your train, or drop the fork's `collect_logs.sh` + `update_result.txt` and open an issue on the upstream `MacsInSpace/mib-cluster-map`.
- `PROFILE_MATCH_OK` — the unit is in the fork's tested set. Continue with `Install`.
