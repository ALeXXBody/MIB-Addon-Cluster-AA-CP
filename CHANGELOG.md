# Changelog

## 0.1.0 — 2026-11-04
- Initial mod packaging for M.I.B.
- Four GEM screens: status / install / uninstall / collect fork logs.
- M.I.B. launcher block (`Launcher-sda0.esd.append.md`).
- Ships fork's sh-helpers + per-train profiles.conf + Nav / turn-arrows jars from upstream for review; per-unit binaries are built separately.
- Full fontious README, install.md, car-test-notes.md and FORK.md (linked from upstream).

### Turn-card clear + turn-info strip (v0.4.3)
Two new GEM switches, both from docs/android-auto-research.md's findings:

- **"Turn-card clear"** (top strip / sides / middle band / OFF): presets that
  write the *official* `UiConfig.content_insets` block into the cluster's
  video configuration via `GAL_SECONDARY_UI_CONFIG_HEX`. Confirmed this fork's
  hook already writes the exact payload structure (field 11 = 0x5a tag, one
  insets field) from `build_insets_payload()` in `src/video_sink_hook.c`
  (the mossyhub-safe wire: field 1 margins, field 2 content insets, field 3
  stable, field 4 theme). No engine change; takes effect on the next
  phone connection or unit reboot. OFF restores the standard layout.
- **"Turn info strip"** (ON / OFF): the fork player gained a text strip at
  the bottom of the cluster map, showing what the hook decoded from the AA
  navigation channel (road name | ETA | distance) — the standard AA
  "non-video instrument cluster" content Google's own DHU emulates, drawn
  in the fork player because the unit's dmdt has no text surface.
  Implementation: hook writes `/tmp/gal_nav_info` (bounded ASCII line, 
  atomic) when `GAL_NAV_INFO_FILE=1`; player `turnstrip.h` adds a 5×7-font
  strip into the rendered Y plane (luma-only, no GL state) reading
  `/tmp/gal_nav_info` + the live switch file `/tmp/stream-player.navstrip`
  ("1"/"0"; polled every second). Both switches live: ON/OFF without
  restarting or re-installing. Defaults are 1 (strip on), so an install
  shows the feature; turning it off is one GEM click.
- Rebuilt libgal_hook.so + stream-player (`features-card-20261105`
  hook, same toolchain as v0.4.0). Payload SHA256SUMS regenerated
  (40 files). README/LEDGER updated below.

### Ecosystem research note (v0.4.2)
- docs/related-projects.md: nine sibling/cloned repositories analysed
  (MHI2-altScreen, MHI2Q-CarPlay-AltScreen, mib2-carplay-rgi*, harman-f,
  chefranov, aberbic, 1mikew/mst2, edzenis). Header finding of the sweep:
  the upstream "wheel zoom not possible" conclusion is refuted on this
  Harman MHI2 family — two projects prove DSI-tracer-based wheel reading
  car-side, and the same tracer infrastructure is present in the VW image
  this Addon targets (verified in /eso/hmi/lsd/traceConfig.properties and
  the DSI jars). Proposed as opt-in CLUSTERMAP_WHEEL_ZOOM (not yet
  implemented — needs a car round on the current fork-player build).

### Release pipeline + build docs (v0.4.1)
- `tools/build_release.sh` + `.github/workflows/release.yml`: pushing a `v*`
  tag now builds `MIB-Addon-Cluster-AA-CP-mod-<tag>.zip` (card payload +
  README/install/docs, screenshots excluded) with a `.sha256` sidecar and
  publishes it to a GitHub release; verified locally at 862 KB for the
  current payload.
- The fork tree documents the container-less (native) toolchain build that
  produced the real player: `BUILD_LOCALLY.md` (unpack, the /opt/qnx650
  baked-prefix symlink, the broken g++ symlink fix, smoke test, and the
  exact native player build commands); pointer added to `build_local.sh`.
- Documented switch persistence: unit-side switches survive reboots, a card
  re-install resets them (one click each to restore), Uninstall forgets
  them; Zoom's live file applies mid-session. install.md + README.

### Fork player build shipped (v0.4.0)
- `stream-player` in the payload is now **fork-built from
  mib-cluster-map-generic** (`v1.1.1-beta18-16-g4b43ddf`, built with the
  luka-dev QNX 6.5 ARMv7 toolchain GCC 8.5, ffmpeg 6.1.5 mini). It carries the
  two fork features the upstream v1.1.0 release player does not have:
  **Zoom** (GAL_PLAYER_ZOOM_E4 + /tmp/stream-player.zoom) and the **Keep map**
  cockpit arbiter (GAL_KEEP_MAP).
- ClusterMap screen gained **Zoom 1.0 / 1.15 / 1.35** items (live effect, no
  reboot needed) and a **Reboot the unit** item (M.I.B.'s own reboot script).
- The zoom and keep-map switches now work against this player; they keep
  refusing with a clear message when an upstream-release player is installed.
- Source provenance: the hook, `profile_check` and `libdmdt_flush.so` remain
  the upstream v1.1.0 release bits (unchanged SHAs for the hook);
  `stream-player` was produced locally and its SHA recorded in
  `CHANGELOG-fork.md`.
- Payload SHA256SUMS regenerated (38 files, sorted).

### Verified on the car (v0.3.1)
- Full chain confirmed working on the Tiguan AD1 test car: copy-paste
  install, one click in M.I.B.'s GEM, ClusterMap screen, Android Auto
  map on the cluster with M.I.B.'s payload untouched and no manual file
  edits anywhere.
- The on-car debugging surfaced the real cause of the early
  "Read-only file system" failures: this unit's GEM console runs on the
  core that has no local card reader (the card is a QNET mount of the
  mmx node's device), so the remount ladder now contains
  `on -f <full node name> mount -uw /fs/sda0` and friends. Recorded in
  `docs/car-test-notes.md`.

### Reworked — install with zero file edits (v0.3.0)
- New install model based on M.I.B.'s own documented mod hook: the repo ships a
  `mod/custom.sh`, which M.I.B.'s GEM runs from **M.I.B. -> Advanced Settings ->
  "Run /mod/custom.sh from m.i.b. SD"**. It copies the mod's own
  `greenmenu/cluster-map.esd` screen onto the unit
  (`/net/mmx/mnt/app/eso/hmi/engdefs/`, the same place M.I.B.'s `apps/launcher`
  links `Launcher-sda0.esd` from, and the same write pattern as M.I.B.'s sshd
  mod) and then runs the fork's installer. One click + reboot; the GEM then has
  a top-level "ClusterMap" screen (Status/Install/Uninstall/Keep-map/Verify/
  logs/turn-by-turn).
- Removed the old "append to Launcher-sda0.esd" path and all of `esd/`
  (wrappers, append block, ready-made esd). No manual editing of any file is
  needed anymore and pasted-launcher blocks can go wrong; this hook cannot.
- The fork's proven `greenmenu/` GEM scripts entered the payload unchanged
  (their common.sh already resolved this layout); only the screen's script
  paths were remapped to `/net/mmx/fs/sda0/mod/cluster_map_aa_greenmenu/…`.
- Payload SHA256SUMS regenerated over all 37 payload files.

### Fixed (v0.2.1)
- The launcher snippet in `esd/Launcher-sda0.esd.append.md` used a screen
  declaration the M.I.B. GEM has never recognized
  (`screen cluster_map_aa greenmenu`) and LF line endings, so pasted screens
  never appeared in the GEM. Replaced by a byte-exact, pre-formatted block
  `esd/cm_aa_screens.esd` (ASCII/CRLF, parent `=>M.I.B.<=` — the same pattern
  as M.I.B.'s own `screen vim =>M.I.B.<=`), verified against the real
  `Launcher-sda0.esd` from M.I.B.: merged copy shows the screen as a clean
  top-level GEM entry, CRLF preserved end-to-end.
- README / install.md / append instructions replaced with append commands
  (`cat >>` / `type >>`) plus a Notepad++ fallback and the `cm_aa` search
  check for the owner.

### Changed (v0.2.0)
- De-branded the Addon from "Tiguan": the engine is train-generic (any MHI2 train
  upstream mib-cluster-map profiles). docs/Tiguan.md → docs/car-test-notes.md,
  GEM screen labels and wrapper strings renamed, README reworded to cover the
  full model support surface.
