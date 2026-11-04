# What lives on the unit, per mod/cluster_map_aa_greenmenu

## Added to the card

- `mod/cluster_map_aa_greenmenu/`
  - `enable_hook.sh`, `disable_hook.sh`, `collect_logs.sh` (fork core)
  - `lsd_jar.sh`, `scripts/lib_*.sh`, `scripts/experiments/zoom_test.sh`
  - `scripts/window_fix.sh`, `scripts/turn_by_turn.sh`, `scripts/full_frame.sh`
  - `config/profiles.conf` (fork per-train profile table)
  - `config/framework.json`   (for the unit's dmdt while the M.I.B. install runs)
  - `libgal_hook.so`, `stream-player`, `lib/libdmdt_flush.so`
  - `profile_check` (ARM ELF — the unit's own gal fingerprint detector)
  - `thirdparty/{NavActiveIgnore.jar, VCAndroidAuto.jar}`
  - `GEM/*.sh`, `GEM/cluster-map.esd` (optional — see below)
  - `LICENSE` (the fork's own GPL-3.0 notice)

## Source notes
- The QNX binaries in this mod are from **M.I.B. Addon = Cluster AA/CP**:
  `libgal_hook.so`, `stream-player`, `profile_check` and `lib/libdmdt_flush.so`
  are the upstream **mib-cluster-map v1.1.0 release** bits (MacsInSpace,
  car-tested on the VWG13 / Tiguan / VWG11 / SKG13 / SEG11 / AUG22 / AU37x /
  US-VWG13 trains) plus an additionally compiled `profile_check` (which
  upstream ships in its repo but not in its release zip)
  and `binaries/dmdtgo`, our QNX-Zoom helper, built 2026-11-04.
- The jar files are the same ones upstream ships; the licence file pair
  (`NavActiveIgnore.LICENSE`, `VCAndroidAuto.LICENSE`) keeps their terms.
- The launcher patch (`esd/Launcher-sda0.esd.append.md`) adds 4 GEM screens
  without touching M.I.B.'s own launcher: all 4 run the fork scripts from
  `mod/cluster_map_aa_greenmenu/`.
