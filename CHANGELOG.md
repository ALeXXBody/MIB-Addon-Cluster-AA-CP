# Changelog

### v0.4.20: the card is never written + a diag file on EVERY exit (2026-11-08)

Root cause of the recurring "the SD card is READ-ONLY" reports: **our own
writes**. The addon used to write backups, logs, probes and staging files
onto the FAT card during every run; a FAT volume whose dirty bit gets set
is mounted read-only by QNX on the next boot. That made the addon fail on
the card's write state and made a *phantom* read-only card the explanation
for every failed run.

- **The card is read-only media, permanently.** Backups and logs now live
  on the unit's RAM (`/tmp/clustermap_unit/backups`, `/tmp` for the hook
  log). The persistent recovery copy that uninstall needs is the one kept
  beside the live supervisor config on the unit. `common.sh` no longer
  remounts or probes the card; the phantom "READ-ONLY card" message and the
  whole remount ladder are gone. The card is only ever READ.
- **One diagnostic file on EVERY exit path.** v0.4.19 wrote diag.txt only
  at the end of a run, so a run that stopped during screen generation left
  no evidence at all. `mod/custom.sh` now installs an EXIT trap: every
  exit (success, early failure, signal) writes the bundle. It always lands
  at `/tmp/clustermap_diag/diag.txt` (RAM, guaranteed) and is copied to
  `<payload>/diag.txt` on the card best-effort, once, for convenience.
  The bundle now also carries the script's own narration, so an early
  stop states WHY. `diag.txt.prev` keeps one previous bundle.
- **Shorter card folder: `mod/cluster_aa`.** The shipped payload folder is
  now `mod/cluster_aa` (was `mod/cluster_map_aa_greenmenu`). Every locator
  tries `mod/cluster_aa` first and still finds the old names, so the
  owner's existing card keeps working. The release zip packs
  `mod/cluster_aa/`. Arming accepts `HOOK_ARMED` or the 8.3-safe
  `ARMNOW.TXT`.
- **Quiet, honest console.** The unarmed run says nothing about arming; the
  outcome is one of: `Map install: DONE`, `Map install: FAILED`,
  `Staged only (not armed)`, or `Map already live ... nothing changed`.
  Measured worst case: 17 non-blank lines for an unarmed run (was pages).
  Internal `CLUSTERMAP_*` markers no longer leak to the screen.
- **Rule 2 bug fixed:** the screen-generation block moved fully inside the
  arming gate. Previously an unarmed run still executed it with an empty
  engdefs path and could write `/cluster-map.esd` at the filesystem root.
- **GEM sanity check fixed:** the "scripts missing on the card" loop used
  the old folder name and printed six 4-line warnings on the new layout; it
  now uses the found payload name and prints ONE line.

Offline gate: **31 tests** (added: every-exit-path diag, early-failure
reason in the bundle, no-payload still leaves a diag, already-live verdict,
card-never-written homes, shipped `mod/cluster_aa` discovery).

### v0.4.19: one file to send (diag.txt) + the quiet GEM console (2026-11-08)

Two owner requests, now the default behavior of every install/uninstall and
settings run:

- **One diagnostic file** - mod/cluster_map_aa_greenmenu/diag.txt - written
  automatically by every run (also by the M.I.B. "Run /mod/custom.sh"
  flow, no extra click). Contents: unit/train facts, checked payload
  checksums, card and unit views, arm state, the engdefs LISTING (the
  GEM world, enumerated but not touched), the installed map settings
  (window/DPI/Insets/aspect/zoom/full-frame), the supervisor env KEY
  NAMES for gal (values kept off-card where they do not belong), the
  hook log tail, the backup home record, and the FULL last-run log.
  diag.txt.prev keeps the previous bundle, so a bad run cannot destroy
  the last good evidence.
- **The GEM console is quiet by default.** The child output goes into
  diag.txt; the console shows the curated story (~15 lines): the outcome
  and warnings only (CLUSTERMAP_ markers, failures, view names, the
  staged/restored facts, `unit files:` line, `Map install: DONE/FAILED`).
  Both custom.sh and the ClusterMap screens (install/uninstall/status,
  switch screens) ship this. console_summary.sh is the single filter.

Also this round (per the owner's rules, now enforced in tests):
- unarmed installs stage the hook files but write NOTHING to gal's
  supervisor config, replace nothing, and never edit lsd.sh;
- armed installs back up the unit's stream-player AS IS
  (stream-player.aacluster-original) and the uninstall restores those
  stock bytes;
- GEM registration stays default-off; it only happens in the same
  deliberate armed step (HOOK_ARMED on the card).

Offline gate: 28 tests, including the new diag-bundle contract and the
two-rules rules (byte-identical config untouched unarmed, player backup +
exact restore, GEM untouched unarmed).


### v0.4.18: the surgical revert + the hook can no longer go live from an install alone (2026-11-07)

Owner's car: unit stuck at "green menu starting..." after the first install
that ever completed far enough to inject the hook's LD_PRELOAD into gal's
supervisor config. This release answers the two hard requirements that
came out of it:

- **`rescue_revert.sh`** — a surgical, flash-free revert of EXACTLY what an
  install added on the unit, idempotent, runnable from ANY shell the unit
  can offer (the emergency serial console, SSH/telnet, or the GEM once it
  comes back). It: deletes the engdefs screen file (the GEM parses that
  file on every boot); restores `smartphone_integrator.json` from the
  untouched backup the install kept ON THE UNIT
  (`smartphone_integrator.json.gal-dualscreen.original`) or the card copy;
  removes the hook files; removes the NavActiveIgnore.jar line + markers.
  Everything else — FEC, coding, M.I.B. customisation — is untouched.
- **BOOT-SAFETY DEFAULT: the install no longer arms the hook.** The files
  are staged; gal's supervisor config is left WITHOUT the hook's
  LD_PRELOAD unless the owner explicitly arms it (a `HOOK_ARMED` marker on
  the payload or `CLUSTERMAP_HOOK_ARMED=1` in the environment). A hook
  that is not preloaded cannot take gal down at boot, so the GEM-hang
  class is gone by construction. Arming is one deliberate action.
- **One protocol per cluster, enforced**: if M.I.B.'s own CarPlay Maps VC
  payload (omonob / carplaymaps) is configured on the unit, the install
  refuses before touching anything (rc 4) — the stacking conflict is a
  documented unit-killer.
- Post-write verification of the injected config is aware of whether the
  install was armed or not (the unarmed install's verification no longer
  demands LD_PRELOAD).

Offline gate: 23 tests. New coverage: the armed install DOES inject
(explicit action verified), the unarmed install provably does NOT, and an
M.I.B.-CarPlay stack is refused with the config left untouched.

### v0.4.17

### v0.4.17: the GEM-boot hang round — the install can no longer place an unverified screen file (2026-11-07)

Symptom on the owner's car: after the addon install, the Green Engineering
Menu hangs at its "Green menu starting..." screen. The hazard class this
round exposed: `mod/custom.sh` TRUNCATED the unit's live
`/eso/hmi/engdefs/cluster-map.esd` with whatever the template generation
produced — a failed generation (empty or malformed output) would land a
broken screen file on the unit, which the GEM par选择ses on every boot,
with no recovery path available from the card.

GEM-boot safety contract now enforced everywhere in the screen install:
- the live engdefs file is NEVER truncated with unverified content;
- the generated screen is staged beside it, and renamed in place ONLY
  when it passes four checks: non-empty, contains `screen ClusterMap`,
  contains no unreplaced `@GREENMENU@`, and every script path it names
  exists on the card (checked without subshell-losing pipes);
- a failed generation leaves the unit's screen file as-is and exits with
  an explicit FAIL line (the installer is not run either);
- the previous good screen is kept as `cluster-map.esd.prev`;
- `sync` runs after the screen write (renames through QNET views need it).
The pre-built (fallback) screen path got the same safety: its hardcoded
`/net/mmx/fs/sda0` prefix is rewritten to the card view this console found
the payload under, then verified, staged and renamed — no raw `cp -p` of an
unverified file into engdefs.

Offline gate extended to 21 tests: full custom.sh flow (payload -> screen
write -> installer), a deliberately broken template leaves the live file
INTACT, and the template-less fallback rewrites/stages safely.

### v0.4.16

### v0.4.16: the offline car-simulation gate (venv + pytest) — install/uninstall lifecycle PROVEN offline (2026-11-06)

New: `tools/venv_test.sh` — a Python venv + pytest gate that builds a
SIMULATED unit in a private mount namespace (stubs for `mount`/`on`,
genuine tmpfs-view semantics) and drives the REAL payload scripts offline:
18 tests pass, including the full install→uninstall lifecycle with the unit
addressable ONLY through the FQDN QNET spelling (`/net/mmx.mibhigh.net/…`)
and every other view genuinely read-only.

Found and fixed in the same gate (offline, before the next car round):

- `enable_hook.sh` resolved its supervisor config through the hardcoded
  /mnt/system spelling BEFORE any ladder — on a console that only resolves
  the FQDN view the install aborted before starting. A `system_pick_view()`
  read-resolution now picks the reachable spelling first; the write ladder
  still re-points the target to the view that accepted the write probe.
- The `/eso/lib/gal_dualscreen/libgal_hook.so` short-alias verification
  aborted the install when the CONSOLE could not see /eso (it is resolved
  by the RUNTIME node, not the console). It is now an explicit NOTE with
  the staged file path; the install continues on the strength of the
  write-view verification, and Status/Verify check the alias after boot.
- The "Could not locate children.gal.envs" failure now prints what the
  patcher actually read, so a defective unit config is diagnosed on the
  console instead of a guess round.
- `lib_app_mount.sh`: system views get the same candidate list shape as
  the app views (FQDN first-class member).

The sim suite (tools/car_sim/) is part of CI from now on: ladder choice,
probe-through-same-spelling, card discovery on FQDN/QNET views, write-home
fallback, engdefs view reporting, status/verify view retries and the
lifecycle all break loudly when a view regression creeps in.

### v0.4.15

### v0.4.15: the unit's partition views are single-spelled now, everywhere (2026-11-06)

Owner evidence: the card is NOT read-only; the unit shows mounts only as
`/net/mmx.mibhigh.net/…`. That pins the last hard-blame class: write and
check paths hardcoding one spelling of the app/system partitions.

- `mod/custom.sh`: the GEM screen registration probes every app view
  spelling (FQDN /net/mmx.mibhigh.net/mnt/app, shorthand /net/mmx/mnt/app,
  /net/rcc/mnt/app, local /mnt/app) and writes the screen through one that
  is reachable AND writable through the same spelling — printing which won.
- `lib_app_mount.sh`: `APP_VIEWS` ladder gains the FQDN form; the write
  probe runs through the same spelling writes will use
  (`app_probe_view()`); `APP_LADDER_FORM` names the winning form on the
  console; `app_pick_view()` serves read-only files.
- `enable_hook.sh`: jsonlint + validator library paths resolved via the
  picked view BEFORE the first validation; app + system ladder verdicts
  printed; system ladder re-points TARGET_CONFIG + backups to the view
  that passed the write probe.
- `disable_hook.sh`: restore ladder view-probed; jsonlint view-resolved.
- `greenmenu/{install,uninstall,status,verify}.sh`: view-aware reads and
  engdefs/screen cleanup (helpers `_unitapp`/`_unitsys`; verify retries
  manifest paths across spellings).
- `mod/custom.sh` self-check loops all four app views (ok-count, focused
  diagnosis, no bare MISSING lists).
- LEDGER fact added: a false "card READ-ONLY" report on a writable card
  means a view probe failed — never the card — and installs must not stop.

### v0.4.14: the drift check was lying + never-block-on-RO-card + M.I.B.'s tools contract (2026-11-06)

- **`tools/payload_sync.sh` rewritten (both false-OK bugs fixed):**
  `diff -u … | head` had masked the honest exit status behind head's
  always-success status, so the checker reported "OK, no drift" while the
  fork mirror drifted for weeks. It also lacked the layout rules that make
  a two-repo mirror sound: fork-only extras (binaries/, config/,
  custom.sh, README.md) are whitelisted; the fork's NESTED copies
  (`scripts/enable_hook.sh`, `scripts/disable_hook.sh`,
  `scripts/collect_logs.sh` — the copies the fork's M.I.B. screens run)
  are explicitly governed to byte-match the Addon's canonical root files.
  `tar --exclude` order fixed (POSIX tar applies trailing `--exclude`
  positionally and silently ignores it).
- **`enable_hook.sh` / `disable_hook.sh`: payload-root resolution by
  content.** CARD_ROOT is the folder that actually holds
  `libgal_hook.so` — one level up when the script copy is reached from the
  fork's nested `scripts/` layout. Both M.I.B. entry points
  (`mod/custom.sh` screen chain and `esd/scripts/cm_aa_install.sh`) now
  behave identically, with zero duplicate maintenance.
- **A read-only card can no longer stop the install.** The greenmenu
  installer no longer hard-exits on the card probe. `enable_hook.sh`
  gained `ensure_write_dir()`: the card's `backups/`+`logs/` when
  writable, `/tmp/clustermap_unit/{backups,logs}` otherwise, with the
  chosen home recorded into the card's `last_install_paths.txt` or the
  unit's `/tmp/clustermap_last_paths` — and `disable_hook.sh` reads BOTH
  sources to find the install's backups for uninstall/restore. Verified
  functionally against a genuinely read-only filesystem (both branches).
- **QNET view spelled the way the owner's unit does.** find_card's
  candidate + fallback lists carry `/net/mmx.mibhigh.net/fs/sd{a,b}0`
  next to the `/net/mmx/…` shorthand; the card remount ladder uses the
  mount point from the mount TABLE (any slot), not a hardcoded
  `/fs/sda0`; card-path bootstrap for M.I.B.'s bundled tools uses the
  slot-aware views (${_v}/apps/sbin) plus QNET shorthand/FQDN forms.
- **M.I.B.'s bundled-tools contract.** M.I.B. bundles its own missing
  binaries (sed, awk, cut, tee, sha1sum, …) on ITS card and prepends that
  folder to PATH (config/GLOBALS). Our payload runs from the same card, so
  `find_card()` does the same (defense-in-depth: our scripts also stay
  printf/tr/diff/grep -o-free, with `tools/gem_portable_check.sh` in CI
  failing any regression, and `cmp` uses a size-verified fallback).
- `mod/custom.sh`: self-check shows "ok" via reachable unit views
  (/mnt/app + /net) and prints a targeted diagnosis instead of a bare
  MISSING list; its "install did not finish" advice matches the new
  read-only-is-not-fatal behavior.

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

### Mount-form ladder (v0.4.13): install works from ANY GEM node view
- lib_app_mount.sh: new `app_mount_rw()` tries /mnt/app (plain),
  /net/mmx/mnt/app, /net/rcc/mnt/app, `on -f mmx/rcc mount -uw /mnt/app`,
  verifying each with a real write probe, and selects the working alias
  ($APP_RW). app_mount_finish remounts that alias read-only.
- enable_hook.sh: all unit-side writes (gal_dualscreen dir,
  libdmdt_flush.so copy, stream-player install, CarPlay safe-area/nav
  files, NavActiveIgnore+TBT markers, smartphone_integrator + backups)
  go through the working alias; the /mnt/system path ladder repeats the
  same selection and re-points TARGET_CONFIG when the network view wins.
- This is the M.I.B. toolbox's own trick (apps/launcher and its docs use
  /net/mmx/mnt/app + on -f mmx), applied to our install so the same GEM
  screen works regardless of which node the GEM console runs script
  bodies on.

### Screen generated from find_card's result (v0.4.11)
The engdefs screen file is now GENERATED by mod/custom.sh from a TEMPLATE
(greenmenu/cluster-map.template.esd) with @GREENMENU@ placeholders — the
located card path replaces them, so the GEM screen's script paths are
always the card view custom.sh actually found (any slot/view/layout).
A paths self-check prints every item; M.I.B.'s own reboot (on-unit) is
not flagged. The plain cluster-map.esd copy remains as a fallback when a
card carries no template.

### Screen design v2: single-entry GEM switch router (v0.4.10)
From the owner's v0.4.7 screenshots (the "Script not found" error tree):
the GEM screen file now routes EVERY switch through one script
(`greenmenu/menus.sh <verb> [arg]`) — no entry in the engdefs screen
references a directly named switch script anymore, so a partial/older
card copy can produce at worst one clear "menus.sh not found" line and
custom.sh's missing-on-the-card scanner pins down exactly which dispatch
file was missing. menus.sh routes: install/uninstall/status/logs/tbt/
verify/porting(+full)/zoom(+off)/navstrip/cardclear(+off)/remote/keep_map/
full_frame. The fork payload mirrors it; SHA256SUMS regenerated (42 files).

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
