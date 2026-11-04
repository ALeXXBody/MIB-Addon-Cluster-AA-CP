# Install this M.I.B. mod

## Pre-req
- M.I.B. installed and GEM running (V3.8.0+ recommended).
- Car: Tiguan AD1 AID10-compatible, or Golf / Passat B8 family with AID.
- Cluster firmware NOT patched with M.I.B.'s `CarPlay Maps VC` omonob payload — this mod is Android Auto only; do NOT stack both.

## SD-card staging
1. Format a card FAT32, copy your existing M.I.B. root to it (keep ALL of M.I.B.: `Launcher-sda0.esd`, `esd/*`, `mod/*`, `apps/`, `patches/`, `metainfo2.txt`).
2. Copy the **fork's per-unit binaries** to `mod/cluster_map_aa_greenmenu/binaries/`: `libgal_hook.so`, `stream-player`, optional `libdmdt_flush.so` and `dmdtgo` — the upstream MacsInSpace v1.1.0 release already carries these ready to copy into the SD card's `mod/…/binaries/`.
3. Copy `esd/scripts/cm_aa_*.sh` to your existing `esd/scripts/` folder already present on the M.I.B. card.
4. Open `Launcher-sda0.esd` on the SD card and paste the screen block from `esd/Launcher-sda0.esd.append.md` at the end of the file.

## Running
Insert the SD card into **SD slot 1** and enter M.I.B.'s GEM.
Use the new **Cluster Map — Tiguan fork (AA→VC)** screens.
Use `Status` first to verify the hook is detetectable by the unit.
Use `Install` to write the fork's deltas into the unit's `/mnt/app/`.
Connect a phone to test.

## Uninstalling
Run the `Uninstall` screen. That runs the fork's `disable_hook.sh`, which restores `smartphone_integrator.json` + removes the fork's lib/player/utils. M.I.B.'s GEM screens stay available; M.I.B. is untouched.

## Troubleshooting
- `FAIL: MMX_FILESYSTEM_NOT_FOUND` — the script could not find `/net/mmx/ifs/lsd.jxe`; are you sure the unit is MHI2?
- `PROFILE_MISMATCH_*` — your gal/libautoreceiver doesn't match any profile in the fork's `config/profiles.conf`. Use the upstream toolchain's `tools/find_profile.py` to add your train, or run the fork's `collect_logs.sh` and open an issue with the dump attached.
- `NAVIGATION_PAYLOAD_INVALID` — the Nav jar in `thirdparty/` doesn't match the upstream shipped one; download the original from [jilleb/mib2-toolbox](https://github.com/jilleb/mib2-toolbox) or from the fork's repo.
