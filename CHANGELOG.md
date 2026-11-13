# Changelog

### v0.4.22: the card copy of diag.txt is verified and spoken aloud (2026-11-08)

The report that started this round: "there is no diag.txt file on the card
after the add-on install… aa is showing in cluster". The map installed fine;
the card copy had failed **silently** — v0.4.21's collector did
`cp ... 2>/dev/null` inside its exit trap, so a card the unit cannot write
(read-only FAT from an unsafe eject — the known QNX dirty-bit behaviour)
looked like "nothing".

- The delivery is now **verified and spoken**: the console always prints
  `diag bundle: /tmp/…` and either `card copy: <path>` (a checksum-verified
  copy) or `card copy: NOT WRITTEN - the card is read-only to the unit`,
  followed by the PC fix and the picture-tuning facts (`GAL_PLAYER_WINDOW`,
  `GAL_SECONDARY_DPI`, `GAL_SECONDARY_INSETS`, zoom, full-frame) printed
  right on the GEM screen — a photo of the screen is enough to fine-tune
  even with no card copy.
- **Write-without-cp**: the copy uses shell redirection (`cat > file`) and a
  checksum check instead of `cp` — the unit shells bundle their own tools,
  and a missing `cp` was one of the ways the copy could silently fail.
- **Every card spelling is probed**: the payload folder is reachable under
  several views (`/fs/sda0`, `/net/mmx/...`, FQDN ~) and only SOME accept
  writes; the collector probes each with a real 0-byte write and copies
  through the first that takes bytes, then verifies.
- **Real bug found by the offline suite in the process:** writing the
  writability probe as `: > file` can ABORT the whole shell (POSIX: a
  redirection error on a special builtin exits — dash does exactly that).
  All three such redirections in the add-on (console log, bundle scratch
  file, card probe) are now subshell-isolated.
- Same truthful narration on every path: the one-click installer (`custom.sh`
  exit trap) and every GEM menu verb (`menus.sh run_quiet`, `diag` verb).

Offline gate: **37 tests** (new: card read-only is said out loud with the
tuning facts; the copy falls through to a writable spelling and is named;
every run narrates the card copy on success).

### v0.4.21: one click = install + arm + GEM screen + diag (2026-11-08)

Car-round feedback asked for the two manual steps (arm the map, fetch the diag) to disappear. They are now automatic:

- **The release zip ships ARMED** (`mod/cluster_aa/HOOK_ARMED` is in the
  zip, created by `tools/build_release.sh`). One "Run /mod/custom.sh"
  validates + installs the GEM screen, stages **and arms** the hook, backs
  up the stock player, and writes the diagnostic file. Then reboot; the map
  is on the cluster. The repository's own payload stays unarmed and the
  build fails if that ever flips, so tests/dev can never arm a unit by
  accident. `tools/check_release_build.sh` (now part of the gate) asserts
  the whole one-click contract on a real build.
- **GEM "2b. Make the map LIVE"** — new ClusterMap entry that arms the hook
  from the GEM itself (`menus.sh arm`), so the stage-only path needs no card
  edit and no PC. To go stage-only, delete `HOOK_ARMED` from the card.
- **Ordering kept as a safety rule:** the screen file is validated and
  written FIRST; any failure there stops before the installer, so a broken
  screen can never meet a live hook. `.prev` and the persistent supervisor
  backup are unchanged.
- **Fixed: every ClusterMap menu entry was dead.** `menus.sh` sourced
  `greenmenu/lib_app_mount.sh`, which does not exist in the payload — the
  unreadable source line exited the dispatcher with rc 2, so clicking any
  item did nothing. It now loads the real `scripts/lib_app_mount.sh` and a
  missing copy can never kill the menu. Regression test parses the screen
  file and asserts every `menus.sh <verb>` has a dispatcher case (and that
  the template and the pre-built screen agree).
- Stale console paths removed from the dispatcher messages (they still named
  `mod/cluster_map_aa_greenmenu/diag.txt`).

Offline gate: **34 tests** (added: GEM arm makes a staged install live,
arm is idempotent, dispatcher covers every screen verb, release-zip
one-click contract).

### v0.4.20: the card is never written + a diag file on EVERY exit (2026-11-08)

Root cause of the recurring "the SD card is READ-ONLY" reports: **our own
writes**. The add-on used to write backups, logs, probes and staging files
onto the FAT card during every run; a FAT volume whose dirty bit gets set
is mounted read-only by QNX on the next boot. That made the add-on fail on
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

Symptom on the owner's car: after the add-on install, the Green Engineering
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
  are explicitly governed to byte-match the Add-on's canonical root files.
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
The subscriber ask: "Don't enter GEM each time — control the add-on from the
M.I.B. unit". The AA-side answer is: the add-on's cluster input channel
carries the unit's own OK/rotary events (the hook owns that channel), so a
set of gestures can drive the Add-on's own switches *live* — no GEM, no
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
the car test here should confirm the same happens on the Add-on before any
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
  this Add-on targets (verified in /eso/hmi/lsd/traceConfig.properties and
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
- De-branded the Add-on from "Tiguan": the engine is train-generic (any MHI2 train
  upstream mib-cluster-map profiles). docs/Tiguan.md → docs/car-test-notes.md,
  GEM screen labels and wrapper strings renamed, README reworded to cover the
  full model support surface.

## v0.7.5

### Fixed
- Steering-wheel (cluster remote) finally arms: the hook taps the unit's
  outbound `InputReport` path and reads `/tmp/gal_remote` per gesture (the
  inbound path only ever carried the phone's binding).
- Install no longer falsely fails: the system-partition probe writes at
  `etc/eso/production` (where the config actually lives) instead of the
  mount root, and tries `on -f mmx|rcc` forms; a repeat install is now a
  no-op (awk file compare, since this unit has no `cksum`/`cmp`).
- Switches now write the bare values the hook reads (`/tmp/gal_remote`
  single char, `/tmp/gal_hires` `%d`, `/tmp/gal_idr_pump` `%ld`,
  `/tmp/gal_uiconfig` `T,B,L,R`); `GAL_UICONFIG=1` is set so Position's
  live send works; switches remount the app partition read-only again.
- A card-root `gal_dualscreen.conf` is now treated as the live settings
  file (union with the unit copy); the card file is only created as
  fallback.
- Diagnostics: §5 reads the `gal` child's own `LD_PRELOAD` (no false
  positives from the stock `mirrorlink` child); §7 dumps every `GAL_*`/
  `CLUSTERMAP_*` key from the file the hook actually loads (card root wins)
  plus the shadowed unit copy; §8 uses a whole-file envs extractor; §9
  searches every log home including `/fs/sdb0/logs/gal_dualscreen.log`.

### Added
- `VERSION` file (v0.7.5) on the payload.
- `tools/car_sim/test_v075_runtime_contract.py` (11 tests).

## v0.7.6

### Fixed
- The console can no longer hide the reason for a failed install. The v0.7.5
  car photo proved the curated summary missed lines like "Generated
  supervisor config failed jsonlint validation"; console_summary.sh now
  surfaces every failure shape, and a failed install prints the last lines
  of the run log directly on the GEM console.
- A mislabelled persistent recovery copy (one that already contains the
  hook) no longer stops every future install: it is rebuilt from the guarded
  untouched copy instead of refusing forever.

### Changed
- run_verdict.sh treats the new failure shapes as a failed run, so the GEM
  wrapper shows STOPPED and the error lines instead of a silent DONE.

## v0.7.7

### Root cause (owner diag 621e3b24, v0.7.5 run)
The full log ended at jsonlint-OK and jumped to CLUSTERMAP_INSTALL_FAILED
(code 1) with nothing in between: `_err=`mount -uw ...`` probe assignments
inside the v0.7.5 ladders kill the whole script under the unit's stricter sh
when the probe fails (rc=1, no message). dash (the car-sim shell) suppresses
errexit inside functions called from `if`, the unit's shell does not — which
is exactly why every offline test was green while the car died silently.
v0.7.4 survived because its ladder used `mount -uw ... || continue`.

### The same diag also showed
- The unit is ALREADY ARMED: the v0.7.5 hook binary is on the unit (sha1
  matches the card), the gal child carries LD_PRELOAD + 4 GAL_* envs, the
  settings copy is complete — and the hook has never run (no hook log, no
  runtime files). The map is one reboot away.
- Every reinstall after the arming died on the system ladder instead of
  skipping: the v0.7.5 byte-for-byte skip compare was too strict.

### Fixed
- Every probing assignment now carries its own `||` guard
  (`_err=`cmd` || _rc=$?` / `|| true`) — no shell can kill the script
  silently there anymore.
- An EXIT trap guarantees enable_hook.sh can never stop without printing a
  FAIL line, whatever kills it.
- The reinstall skip is semantic now: every entry the install would inject
  must already be present, verbatim, in the gal child's envs (order and
  formatting no longer matter).
- diag §9 now ANSWERS: armed + no hook log => "the hook is armed but has
  NOT run yet — reboot the unit, then Save logs again".

## v0.7.8

###diag.txt now answers the reboot question too
- §9 verdict logic: /tmp is wiped at every boot, so the install-home marker
  distinguishes "no reboot since the install" from "fresh boot and the hook
  STILL never started". The first case says reboot; the second names the
  prime suspect (gal cannot resolve the preload path on its node) and
  points at §4b.
- §4b: hook .so presence + sha1 per unit view (local / m m x FQDN / mmx
  shorthand / rcc) — a hook binary that landed on one node's app partition
  can be invisible to gal on the other node.
- §9: when a hook log exists, the bundle now prints the init line and the
  first 12 lines, plus the tail.
- §8: process names in the supervisor config (gal's siblings), one line.

## v0.7.9

### Fixed — every switch is now reachable on the owner's GEM
The owner could see only the first ~9 rows of the ClusterMap screen: his
GEM 4.12st renders about 9 rows and never reached the rest of one long
list — so Hi-res, Sharpness pump, Wheel trace, Cluster remote and the
presets "did not exist" for him although the screen file listed all 46
(the diag §6b proves the file was complete and every path ok; two entries
were even duplicated in the template).

The screen is NESTED now (screen design v3): every screen stays under 9
rows and the sub-screens appear as entries of their parent — the same
parent/child mechanism M.I.B.'s own tree uses.

    ClusterMap            Status, Install, Make LIVE, Uninstall, Save logs
    ├─ ClusterMap_picture     Sharper ON/OFF, Zoom 1.0 / 1.15 / 1.35
    ├─ ClusterMap_position    Position UP/DOWN/WIDER/NARROWER/standard (live)
    ├─ ClusterMap_hires       Hi-res 1280x720 ON/OFF, Sharpness pump ON/OFF
    ├─ ClusterMap_wheel       Cluster menu ON/OFF, Wheel trace ON/OFF,
    │                         Cluster remote ON/OFF
    ├─ ClusterMap_presets     ETA card TOP/BOTTOM/LEFT/RIGHT/OFF
    ├─ ClusterMap_clear       Turn-card clear ×4, Turn info strip ON/OFF
    └─ ClusterMap_more        Keep-map ON/OFF, Verify, arrows, porting ×2, Reboot

Also de-duplicated the template (hiresen/idrpump blocks were listed twice).

## v0.7.10

### Fixed — menu labels are short now
The owner asked for 4-5 word labels instead of 10-15 word ones. Every
script entry label in the GEM screen is now 5 words or fewer; screen
titles are exempt. A static test guards the regression.

### Fixed — diag now captures the decisive mid-log events
The previous diag's §9 only kept the first 12 and last 120 lines, so the
mid-session events (player.spawn, aap.playback, aap.video_focus,
secondary.video_config, primary.register, service.class, impl_at_sink,
stream.mode, stream.open, stream.idr, focus.healthy, fix.config) were
invisible. They are now captured verbatim, plus a new §9c listing gal and
stream-player processes (pidin) and stream-player logs — the exact
evidence needed to settle "the hook runs but nothing shows".

## v0.7.13 — full audit repairs + qnxsh runner

### Fixed (shell layer, audit rounds 1–12)
- `position.sh`: removed dead assignments using unset `NOW_DIR`/`NOW_R`.
- `navstrip.sh` / `card_clear.sh`: added `APP_WRITABLE + trap app_mount_finish`
  (partition no longer left writable on interrupt); replaced `sed -i` with
  tmp+mv rewrites (no torn writes on FAT/QNX); navstrip live file now goes
  through `$GAL_RUNTIME_DIR`.
- `scripts/window_fix.sh`: uses the app ladder + trap instead of hardcoded
  `/mnt/app` (wrong view on FQDN-only consoles).
- `menus.sh`: removed the self-cancelling `trap 2 / trap '' 2` (SIGINT is no
  longer ignored for the whole child); quoted the log path.
- `custom.sh` (one-click flow): now runs the same `run_verdict.sh` verdict +
  ERROR-lines contract as GEM presses (its failures were verdict-less
  before); quoted `$OUT`; script-existence gate works for `/fs/` views too
  (was vacuous off `/net/`); install-OK markers surface in the summary.
- `console_summary.sh`: covers bare `INSTALL_FAILED`, `Uninstall FAILED`,
  `NOT SUPPORTED`.
- `check_gem_esd.sh`: validates the template's 40+ `@GREENMENU@` wrappers
  (previously invisible to CI) and matches parents exactly.
- `check_manifest.sh`: portable null-delimited hashing, `mktemp` diff file.
- `tools/build_release.sh`: no longer wipes `dist/`; version-sorted tags;
  loud failure if the APPLY guide step fails. `check_release_build.sh`
  cleanup scoped to its own artifacts.
- ESD: stanza indent fixed; literal `\n` dropped from the Reboot label.

### Fixed (hook C layer, audit rounds 13–18)
- Wheel trace arm requires a full `len==1` match like the other single-char
  files (`"10"` no longer arms tracing); removed the pre-parse trace log
  that printed hardcoded `key=0 action=0`.
- `ui_config` poll rejects truncated lines (`sscanf==4` required, rejected
  lines logged) instead of sending partial insets.
- Removed stray `fopen(… "X")` fd leak on every OK press.
- Length-skip in the InputReport parser is bounds-checked (was over-read).
- ACK-socket accessors take the stream lock (were unlocked cross-thread reads).
- `vc_player_start()` returns spawned/skipped with a log line; the focus
  controller stamps `g_spawn_ms` only on a real spawn (a no-op no longer
  burns backoff or logs a phantom `player_exit_before_grant`).

### Fixed (test-harness fidelity gaps)
- All `mv new existing` sites are FAT-safe (`rm -f` dest first, `cat`
  fallback): lib, frame conf, enable_hook (8 sites), custom.sh engdefs.
- `jsonlint` stub actually parses JSON (lenient on trailing commas like the
  unit's); corrupt-config installs now fail in-sim instead of passing.
- New `make_root_read_only()` (root refuses, subdir works) and `Car.reboot()`
  (wipes RAM state, keeps persisted settings) helpers.
- `pidin` / `netstat` stubs with canned QNX output; diag §9c/§9d parsing
  covered by test.
- All single-command backtick substitutions in the install path carry `||`
  guards (CARD_ROOT, expr math, cp_setting, ENTRY_COUNT).

### Added — qnxsh runner
No installable shell reproduces the unit's errexit-in-function behavior
(dash, bash, busybox ash, mksh, posh, zsh all probed — all survive where
the unit dies). `tools/car_sim/qnxsh.py` closes it by source
transformation: bare single-command substitutions become
`VAR=`cmd` || exit 127`, then the script runs under plain sh. Guarded
lines are byte-identical, so qnxsh differs from plain sh ONLY where the
unit would have died. `Car.run_qnx()` + 5 regression tests prove the
current tree QNX-clean (full install, repeat-install skip, total-refusal
live arm). 84/84 car-sim green; `audit_wiring.sh` ALL GREEN.

## v0.7.14 — the wheel tap reads the cluster's own channel + hi-res stops arming nothing

### Fixed — steering wheel (root cause, owner's diag 116031ee)
The hook taps the unit's outbound `InputReport` path but only accepted
channels whose class table entry contains `InputSource`. The class table
is filled from `registerService`, which the hook-created cluster input
service never passes — so the cluster's own input channel keeps an EMPTY
class forever, and the filter dropped exactly the channel the wheel uses
when the cluster map is shown (car-verified: the phone's 0x8002 binding
arrives inbound on that unclassified channel, and zero tap lines appear
despite trace ON across two live sessions). The tap now also accepts a
channel the phone bound with 0x8002 and marks the classification as
inferred in the log. Tap lines are logged whenever the trace OR the
remote is on, so actioned presses are visible without the trace.

### Fixed — Hi-res ON no longer arms nothing
`event=secondary.hires result=skipped reason=ui_config_hex_present`:
the hook refuses hi-res while a `GAL_SECONDARY_UI_CONFIG_HEX` override is
present (it replaces the insets wholesale), but the switch persisted the
key and reported success. Hi-res ON now clears the override in the same
write — same rule as Position — and says it must be re-applied; Hi-res
OFF leaves the user's preset alone.

### Fixed — diag now keeps every recent press
Only the LAST run reached §§11/12, so an earlier failing press in the
same round was invisible. New §12b carries the tails of every other
recent menu run log.

## v0.7.15 — the diag keeps everything

### Changed — diag bundle keeps every action in full (owner request)
Until this add-on fully works, no run may destroy evidence:
- §12 keeps the ENTIRE last run (the 400-line cap is gone).
- §12b keeps the FULL log of every other recent press (the 30-line tails
  are gone) — an earlier failing press can never hide again.
- New §12c keeps the console narration (`console.log`) in full.
- The bundle history is now three generations (`diag.txt` + `.prev`,
  `.prev2`, `.prev3`) on the unit and on the card.

### Fixed — hook log rotates instead of truncating
`gal_hook.c` truncated the log to zero at 1 MB, destroying the boot's
early decisive lines (init, grants, spawns) forever. It now renames the
full log to `<log>.prev` and starts fresh (bounded at 2x max, with an
`event=log.rotate` marker joining the generations). The diag collects
the previous generation in full (§9).

## v0.7.16 — every small error now says why and where

### Fixed — the last two silent paths (owner: "will any small error tell why and where?")
Verified first: `live_write` already speaks on failure, and every
persist path prints its outcome — but two holes remained, both closed:
- Hook: successful wheel-menu presses only reached the debug log, failed
  file writes were silent, and a tap filtered for lack of binding left no
  line. Now `cluster.menu.event`, `cluster.remote.strip/card/zoom` log at
  INFO on success AND on `result=failed reason=cannot-write`; the tap
  filter logs a one-shot `result=filtered` naming channel, id and class.
- Switches: `run_quiet` ignored the child's exit code, so a child that
  died WITHOUT its own reason read as DONE. It now appends
  `FAIL: <verb> child <script> stopped rc=<n> without its own reason`,
  which flips the verdict to STOPPED and lands in the bundle.

## v0.7.17 — the wheel path becomes fully visible + press/session correlation

### Fixed — one honest blind spot left (owner diag 62cb83de analysis)
The v0.7.16 diag proved the tap is installed and running (it filtered a
Controller discovery message) yet zero wheel taps appeared across a live
session. Two visibility gaps remained, both closed — no behavior change
otherwise:
- New `event=aap.out` outbound first-sight trace (first 12 messages per
  channel, always on), mirroring `event=aap.msg` inbound. Previously
  anything the tap filter dropped was invisible by construction; now all
  outbound traffic is named with channel, class and message id.
- Every GEM press records its time on the SAME clock the hook log uses
  (`/proc/uptime` monotonic seconds), and the diag records collection
  time on the same clock. A press at monotonic_s=X either falls inside a
  live session window or it doesn't — no more guessing whether the wheel
  was pressed while the map ran.

## v0.7.18 — virgin-unit scrubber

### Added — "Virgin unit (remove all)" (ClusterMap_more screen)
Uninstall left two inert files behind by design (supervisor recovery
copy, screen backup) — fine for normal use, wrong for testing the app
as a new user. The new entry runs the standard restore first (and stops
if that fails, so gal can never be stranded), then scrubs every leftover
the add-on ever placed on the unit: persistent recovery copies, hook
payload remnants, flush .so, safe-area conf, player sidecars, lsd
markers (jars only with our marker — another mod's files are left
alone), both GEM screens incl. `.prev`, card-root shadow confs (moved
aside on the card, never deleted), and all `/tmp` addon files. It then
VERIFIES every path and reports REMOVED / already absent / STILL PRESENT
with reasons — ending in `VIRGIN UNIT: CLEAN` or a named failure.
Card payload, logs and backups are intentionally kept (evidence + source).
A sim test proves scrub-to-zero plus a clean reinstall right after.

## v0.7.19 — the silent death, actually fixed this time

### Root cause (owner diag 30cae7b3, v0.7.18 run)
The install died after the 2nd jsonlint OK with no message and no FAIL
line — on code that had guards plus an EXIT trap. The trap never
existed at runtime: the v0.7.7 safety net (`trap ... 0`) was silently
REPLACED by a later `trap finish 0 1 2 15` in the same file, so every
shell-level death ran cleanup-only `finish()` and exited rc=1 mute.
Every offline gate missed it because nothing asserted trap composition.

### Fixed
- ONE exit trap per script: the reporting lives inside `finish()`
  itself (rc captured first, named FAIL line on any non-zero stop),
  in both enable_hook.sh and disable_hook.sh. The stray `trap -`
  mid-file clearer is gone, so the Java section keeps coverage too.
- The skip compare no longer uses command substitution at all (awk's
  exit code drives the branch) — the substitution class that killed
  v0.7.5 is structurally absent from the death zone.
- Progress markers around the skip check and ladder entry: even a
  SIGKILL/OOM (which no trap can report) leaves its position in the log.
- Ladder error lists use real newlines (`$(echo)` contributed nothing —
  trailing newlines are stripped, so the forms glued into one unreadable
  line on the console photo).

### Tests
- New: exactly one EXIT-trap setter per script + FAIL report present;
  skip check is exit-code driven. 93/93 car-sim green, audit ALL GREEN.
