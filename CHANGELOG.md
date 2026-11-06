# Changelog

## 0.1.0 — 2026-11-04
- Initial mod packaging for M.I.B.
- Four GEM screens: status / install / uninstall / collect fork logs.
- M.I.B. launcher block (`Launcher-sda0.esd.append.md`).
- Ships fork's sh-helpers + per-train profiles.conf + Nav / turn-arrows jars from upstream for review; per-unit binaries are built separately.
- Full fontious README, install.md, car-test-notes.md and FORK.md (linked from upstream).

### find_card: the one card/payload locator (v0.4.5)
- `greenmenu/common.sh` now carries the single `find_card()` function the
  whole code base uses: candidate views come from the running node's mount
  table (any mount point, /fs/... and /net/<node>/fs/...) plus a fixed
  fallback list; the payload must be `mod/cluster_map_aa_greenmenu`,
  `ClusterMap`, loose `cluster_map_aa_greenmenu`, or `mod/ClusterMap`. The
  remount ladder and write-probe run on the REAL card root (a mount point,
  never the payload's parent folder).
- `tools/find_card_test.sh` + `tools/find_card_child.sh`: a tested offline
  regression harness (fake mount + sandbox staging), in CI. All card
  view/layout combinations PASS, including "card mounts but payload absent".
- `mod/custom.sh` mirrors the same discovery (mount table first) for its
  pre-install payload search.

### Cluster remote: no-GEM switches via the cluster's own OK press (v0.4.6)
The subscriber ask: "Don't enter GEM each time — control the addon from the
M.I.B. unit". The AA-side answer is: the addon's cluster input channel
carries the unit's own OK/rotary events (the hook owns that channel), so a
set of gestures can drive the Addon's own switches *live* — no GEM, no
reinstall, no restart of anything:

  * short OK press (<0.8 s) -> cycle the turn-card clear preset
    (top strip -> sides free -> middle band -> off -> top strip …),
    applied live by the new ui-config sender (media message 0x8009 runs
    the same UpdateUiConfigRequest Google's DHU carries, on the cluster
    video channel, with the file-based `GAL_UICONFIG=1` poller and a
    `/tmp/gal_uiconfig` preset file);
  * long OK press (>=0.8 s) -> toggle the turn-info strip live
    (`/tmp/stream-player.navstrip` "1"/"0", same file the GEM's on/off
    switch writes);
  * rotary +- -> zoom in/out live (the existing /tmp/stream-player.zoom
    file read by the player).

Feature is opt-in: GAL_CLUSTER_REMOTE=1 (the GEM switch "Cluster remote:
ON" sets the setting; takes effect at the NEXT gal start). Reason for
opt-in: the hook intercepts OK gestures only when the phone session is
live and the phone has the cluster view; the gestures were car-verified in
the openclcardev/openautolink's working sessions only in their setups —
the car test here should confirm the same happens on the Addon before any
default flips to 1.

Implementation in src/video_sink_hook.c (video_sink_hook.c):
- cluster_remote_{toggle_strip,cycle_card,zoom} + cluster_remote_event();
  runs in cluster_input_message on message id 0x8001 (the input report on
  the cluster channel; probe-only until enabled);
- ui_config_poll in input_inject section: /tmp/gal_uiconfig file sender of
  UpdateUiConfigRequest 0x8009, GEM-free, live, opt-in via GAL_UICONFIG.
Rebuilt libgal_hook.so (cluster-remote-20261106). New GEM switch
cluster_remote.sh (ON/OFF, writes the settings file line, next gal start).

Payload SHA256SUMS regenerated (41 files).

### Card-root remount fix (v0.4.4)
- greenmenu/common.sh now derives the card root correctly for both layouts
  (the M.I.B. mod `<card>/mod/<payload>` layout and the standalone
  `<card>/ClusterMap`), so the remount ladder and the writability probe
  target the mount point, not the card's `mod` folder. This is the real fix
  behind the GEM console's "Can't remount /net/mmx/fs/sda0/mod" line and the
  reappearing read-only failures.
- mod/custom.sh checks that the card still has every script the installed
  screen curls (status/install/keep_map/zoom/card_clear/navstrip) and tells
  the owner to re-copy the repo's mod/ folder when one is missing — the
  cause of GEM's "Script not found: …/card_clear.sh" screens.
- Payload SHA256SUMS regenerated.

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
