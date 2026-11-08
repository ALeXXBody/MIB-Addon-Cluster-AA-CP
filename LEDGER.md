# LEDGER — M.I.B. Addon: Cluster AA/CP

> **Purpose:** every verified fact, decision and signature from building and
> debugging this Addon on the real car, in one file. Read this before doing
> any new work on the project. Update it as findings land; do not re-derive
> what is already written here. Last updated: 2026-11-08 (owner: ALeXXBody;
> agent sessions across OpenCode/GLM; every claim was verified unless it
> says *proposal* or *untested*).

---

## 0. Project state (what exists TODAY)

| Piece | State |
|---|---|
| Addon repo | `MIB-Addon-Cluster-AA-CP` (github.com/ALeXXBody/MIB-Addon-Cluster-AA-CP, `main`) — M.I.B. mod, copy-paste install, zero file edits |
| Fork engine repo | `mib-cluster-map-generic` (github.com/ALeXXBody/mib-cluster-map-generic, branch `aa-vc`, default; `main` = upstream base). Fork keeps: `GAL_KEEP_MAP` arbiter, `GAL_PLAYER_ZOOM_E4` zoom, verify screen, remount ladder, honest guards |
| Install flow (verified on car) | SD1 card → M.I.B. → GEM → *M.I.B. → Advanced Settings → “Run /mod/custom.sh”* → reboots → GEM top-level **ClusterMap** screen works |
| Owner car | VW Tiguan AD1 (`5NA035020D`), `MHI2_ER_VWG13_P4521`, 10.25" AID, related doc: `docs/car-test-notes.md` |
| Working features ON THE CAR (v0.4.0+) | AA phone map on cluster (Google Maps & Waze), Status, Install, Uninstall, Sharper map (no-op on 800×480 window — by design), Reboot item, log collection |
| Untested on car (built, awaiting owner verification) | **Zoom 1.0/1.15/1.35** (fork-built player, live), **Keep map ON** (arbiter) |

## 1. Unit/hardware facts (measured, not guessed)

- SD card at runtime appears from the **GEM console node** as a QNET network mount:
  `/net/mmx.mibhigh.net/dev/sda0t12 on /fs/sda0 type dos (fat32)`; second slot card showed
  as `type exfat` — **harmless, ignore**.
- The GEM **console node lacks tools**: `printf tr cmp diff` are absent (the fork's
  `unit_tools` reports them). Do not depend on these in unit-run scripts.
- The GEM screen scripts run on a node where `/mnt/app/...` paths resolve locally AND
  `/net/mmx/...` is reachable; M.I.B.'s own code uses BOTH styles. `on -f mmx …` works from
  that context (M.I.B.'s own `apps/` uses it routinely).
- The **card remount must be able to reach the mmx node**, not only `/net/mmx/...` names:
  our remount ladder (in `greenmenu/common.sh`) tries local path → QNET device →
  `on -f mmx.mibhigh.net` → `on -f mmx /bin/mount`. First install failed until
  `on -f <full node name>` included (verified by owner's car: works end-to-end after that).
- Honesty guardNeeds: `VOLUME/.rw_probe` style writability probes (mkdir-based), because
  `test -w` succeeds as root on a ro mount. mkdir is the reliable probe.

## 2. Engine facts (which binary knows what)

- Shipped upstream v1.1.0 Tiguan bits: `libgal_hook.so` `afe59ade…67cb8`,
  `stream-player` `4aa21201…8b190` (no longer shipped after v0.4.0 — see §6),
  `lib/libdmdt_flush.so` `4e3202f0…3222f`, `profile_check` built locally
  (`97bc9ba1…3778`).
- **String checks proven** (`grep -a`):
  - `GAL_SECONDARY_PIXEL_ASPECT_RATIO_E4` present in upstream hook → **Sharper map works**
    with upstream binaries (full-frame via margins=0 + pixel-aspect line).
  - `GAL_KEEP_MAP`, `GAL_KEEP_INTERVAL_S`, `GAL_PLAYER_ZOOM_E4`, `/tmp/stream-player.zoom`
    are **fork-source features** — NOT in the upstream v1.1.0 player. With upstream player
    installed, keep-map/zoom switches silently do nothing, which is why
    `keep_map.sh` / `zoom.sh` carry **honesty guards** (refuse with a clear message).
- The hook also carries: `GAL_SECONDARY_MARGINS`, `GAL_SECONDARY_DPI`, `GAL_VC_CONTEXT`;
  the player carries `GAL_PLAYER_WINDOW`. `GAL_SECONDARY_INSETS` is consumed by the hook.
- **IMPORTANT comparisons before claiming a feature works:** after any binary change,
  re-run the string-for-string sanity of §6 to prove which features the installed player
  supports; the green-menu `Verify installed files` screen checks the deployed bytes.

## 3. M.I.B. ↔ Addon integration facts (verified against M.I.B.'s tree)

- M.I.B. registers its GEM screens by symlinking `Launcher-sda0.esd` →
  `/net/mmx/mnt/app/eso/hmi/engdefs/z_Launcher-sda0.esd` (`apps/launcher -all`). Every
  `.esd` file in `engdefs/` adds screens of its own. **Our Addon adds a screen by writing
  `cluster-map.esd` into `engdefs/`** from `mod/custom.sh` (same pattern as M.I.B.'s `sshd`
  mod: `mount -uw /net/mmx/mnt/app` then `cp`).
- M.I.B.'s own launcher screens are declared `screen <id> =>M.I.B.<=` (child of the M.I.B.
  root screen). Our own screen file uses the fork's own pattern `screen ClusterMap Main`,
  proven to work from `engdefs/` (fork's `greenmenu/cluster-map.esd`), script paths
  rewritten to `/net/mmx/fs/sda0/mod/cluster_map_aa_greenmenu/greenmenu/…`.
- M.I.B. GEM has a **built-in hook for mods**: `screen run_custom_script advanced_settings`
  → runs `esd/scripts/custom.sh` → executes `$VOLUME/mod/custom.sh`, at any time, no file
  edits. This is the Addon's only install entry.
- M.I.B.'s launcher file is pure **CRLF**; engdefs-.esd files do not need CRLF (the fork's
  own screen file is LF and works).
- SSHD style `mount -uw /net/mmx/mnt/app` then `cp -prv` to engdefs/ is the proven
  write-pattern for GEM-side mod installs; `esd/scripts/reboot.sh` (`apps/reboot -t 10`)
  is M.I.B.'s own reboot primitive, safe to reuse in our screen.

## 4. Ownership/behaviour of the mod's switches (documented in install.md / README)

- Switches live on **the unit's installed copy** (`gal_dualscreen.conf` beside the hook).
- They survive reboots and sessions; **Zoom additionally applies live**
  (`/tmp/stream-player.zoom`, one float on a single line, picked up within seconds).
- A **fresh Install from the card Resets them** (the card's shipped `gal_dualscreen.conf`
  is the source; the keep-settings wiring exists only as `scripts/lib_keep_settings.sh`
  and is NOT active in this payload — upstream semantics). After a card re-install the
  owner re-clicks each switch (one click each).
- `Uninstall` returns stock and forgets switches.

## 5. Toolchain/build facts (fork-built player shipped in v0.4.0)

- Toolchain: luka-dev/qnx65-armv7-toolchain image 8.5, unpacked at
  `/tmp/qnx-image-root/opt/qnx650` → symlinked to `/opt/qnx650` **because the GCC driver
  has the baked path** `/opt/qnx650/...` for `armle-v7/lib/crt1.o` (env override alone is
  NOT enough).
- After unpacking the image, the `g++`-family entries were **broken relative symlinks**
  (`opt/qnx650/…`). Fix: re-point them onto `arm-unknown-nto-qnx6.5.0eabi-c++` in the
  same dir (see `BUILD_LOCALLY.md` in the fork repo).
- **Containers fail on this TrueNAS LXC**: podman's netavark gives `Sysctl error: Read-only
  file system`, crun fails `controller pids is not available`. **Build natively**
  (`BUILD_LOCALLY.md` pattern) — ffmpeg-mini 6.1.5 SHA-verified tarball →
  `--disable-everything --enable-decoder=h264 --enable-parser=h264`, softfp vfpv3-d16;
  then `player/opengl_gpu.cc` with `-lEGL -lGLESv2 -lsocket -lm`. The produced player
  NEEDS list is identical to upstream's (`libEGL.so.1 libGLESv2.so.1 libsocket.so.3
  libm.so.2 libc.so.3`).
- The v0.4.0 fork player was built from `mib-cluster-map-generic` at
  `v1.1.1-beta18-16-g4b43ddf` (provenance + SHA recorded in the fork's
  `CHANGELOG-fork.md`, section "Local build record (zoom-fork-local)").

### Release archive layout (v0.4.7+)

The customer zip carries ONLY the card content plus two zip-only files that
cannot collide with M.I.B.'s card root (M.I.B.'s own card root ships its
own LICENSE and README.md; a careless whole-root copy would otherwise
overwrite them):
- `mod/` (the card content; the only folder an owner copies)
- `HOW-TO-INSTALL.txt` (generated per tag; the 3 steps + the do-not-copy warning)
- `MIB-Addon-Cluster-AA-CP-LICENSE.txt` (GPL text, named to avoid the clash)

## 6. Release process

- Per-tag release: **push a tag `v*`** → GitHub Action (`.github/workflows/release.yml`)
  runs `tools/build_release.sh "$GITHUB_REF_NAME"`
  → `dist/MIB-Addon-Cluster-AA-CP-mod-<tag>.zip` + `.sha256` → attaches to a GitHub
  release. Verified locally: 862 KB with the v0.4.0 payload (payload + README +
  install.md + docs, screenshots excluded).
- Repo check tools (use from repo root):
  - `tools/check_manifest.sh` — regenerates and diffs `SHA256SUMS.txt`
    (38 shipped payload files, LC_ALL=C sorted).
  - `tools/check_gem_esd.sh` — validates the green-menu screen file(s):
    `screen <name> <parent>` 3-token lines, parents resolvable (known: `=>M.I.B.<=`,
    `main`, `Main`), `/net/mmx/fs/sda0/mod/…` script targets exist in the repo
    (arguments inside the value are stripped: `keep_map.sh on` is one token).
- Every push triggers `.github/workflows/ci.yml`: `sh -n` all scripts + manifest + esd
  checks.

## 7. Research findings (read `docs/related-projects.md` for details)

- Corrected upstream claim: **wheel zoom IS car-proven on this Harman MHI2 family** —
  [joeyQuery/MHI2-altScreen](https://github.com/joeyQuery/MHI2-altScreen) (Audi
  MU0678/P3241) reads wheel notches from the **HMI DSI tracer**
  (`DSIKeyPanelListener#updateEncoder2`, kb **4**, encoder **40**, ±1) and maps them to
  zoom; aberbic (MU1438) built an AA wire zoom report (`aa_zoom_report()`) and a loopback
  UDP bridge (port 19822); chefranov has roller zoom on AU37x.
- **The same DSI tracer exists in the VW image we target** — verified in
  `/tmp/opencode/mib2/unpack/filesystems/MMX2/app/…/eso/hmi/lsd/traceConfig.properties`,
  `DSITracer-VW-H29.319.75.jar`, `DSITracer.jar` + `clientData.bin`,
  `libdsimapproxy.so`, `libdsikeypanelproxy.so`.
- **Proposal (NOT implemented):** opt-in `CLUSTERMAP_WHEEL_ZOOM=1` → scoping the tracer in
  `traceConfig.properties` (keep `.orig`, HMI restart) + a small QNX socket client that
  writes ±steps into `/tmp/stream-player.zoom` (the v0.4.0 player already applies it
  live). Wheel **press must stay unmapped** (joeyQuery lesson: it moves the card/centre).
  Gated behind the owner's car verification of v0.4.0 (see §0 Untested row).
- Waived (checked earlier, not adopted): root-of-card SD manifest (we verify on-unit),
  three-entry GEM trim, MHI2Q/HUD RGI route guidance (separate project family), Album
  art/touchpad (Audi-specific buses).

### Android Auto research (2026-11-05) — see docs/android-auto-research.md

The AA protocol's real knob list — verified against the official DHU guide
(Google's own emulator) and the aasdk .proto mirror — confirms and hardens
our design:
- our Sharper-map/full-frame IS the official `pixelaspectratio` +
  per-edge-margins behaviour (not a hack);
- a video-capable cluster display is officially emulated (`[display:cluster]`
  in DHU configs) — the shape our two-display rewritten discovery response
  matches;
- there is a second, officially-defined NON-interactive cluster surface
  (nav/call status tiles) — status only, no video, no Maps card;
- official video config also carries `contentinsets`/`stablecontentinsets`
  fields our hook does NOT yet emit — this is candidate #1 for moving the
  green nav card out of the route rather than hiding it;
- the AA ButtonCode enum has NO zoom code (vs CarPlay's
  `changeMapZoomLevel`), so phone-side zoom stays impossible — the kept path
  is player-crop (+ tracer-driven steps, §7).

New ranked implementable list (see research doc §6):
1. contentinsets/stablecontentinsets in the cluster video config — card
   relocation experiment (needs one reverse of a video-config field offset
   with tools/armre.py; one car round),
2. road-name + ETA text in the AID lower bar via the already-parsed nav
   messages (uses the fork's nav-translate output + dmdt writer),
3. dial-layout-aware margins via the DSI tracer (bundle with proposed
   CLUSTERMAP_WHEEL_ZOOM),
4. document `GAL_CLUSTER_KEYCODES` (fork supports the knob; docs don't yet),
5. focus/day-night GEM switches,
6. soft DHU sandbox for unit-like video config on laptop between car rounds.

## 8. Waitlist — what the OWNER still owes the project

1. Car-verify the v0.4.0 fork player: Zoom 1.15/1.35 mid-drive, Keep-map ON
   (needs the stock map to actually steal the cluster to be observable), no regressions
   (route starts, reboots, long connects).
2. Status output → fill the "Measured on the unit" card in `docs/car-test-notes.md`
   (window, DPI, insets, context, profile row, sharper-applies, zoom observations).
3. Two driving photos → `docs/photos/` named
   `cluster-map-full-frame.jpg`, `cluster-map-classic-view.jpg` (embedded in README;
   sections exist and show broken images until then).
4. Upstream PR (remount ladder + honest guards + provenance + car data) — after 1–2.

### 2026-11-06: the card-root bug — and the "Script not found" pair

The GEM screenshots from the car showed two failures with one root:
1. `mount: Can't remount /net/mmx/fs/sda0/mod` — common.sh derived the card
   root as *the payload's parent dir*, which in the M.I.B. mod layout is the
   card's `mod` FOLDER, not a mount point. Every remount had been aimed at
   that folder instead of the card root; the read-only probe was placed
   there too. Fixed: the card root now strips `/mod` for the mod layout
   (standalone `ClusterMap` layout keeps the same rule), and the ladder runs
   against the actual mount point (`/fs/sda0` first from the console view of
   the card, then the net forms). The write-probe sits at the card root.
2. `"Script not found: .../card_clear.sh top"` — the screen file in
   engdefs/ comes from the CARD's `greenmenu/cluster-map.esd`; if the card's
   mod folder has an older/partial copy, the unit's screen points at files
   the card does not have. mod/custom.sh now checks the screen's script list
   and prints a clear instruction ("copy the repo's mod/ folder again") when
   the card lacks one.

### 2026-11-06 (2): ONE canonical card locator — the user's requested "find card" function

The miss: the first fix was still string-path patching. The owner's actual
request — a function whose result everything uses — is now implemented:

- `greenmenu/common.sh`'s **`find_card()`**: derives candidate views from
  THIS node's mount table (every mount point: `/fs/...`, `/net/<node>/fs/...`,
  anything else mounted), then the fixed fallback list; finds the payload in
  ANY of the four layouts (`mod/cluster_map_aa_greenmenu`, `ClusterMap`,
  loose `cluster_map_aa_greenmenu`, `mod/ClusterMap`); sets `VOLUME` (the
  card root, a real mount point) and `PKG`. The remount ladder + write-probe
  then run on the real card root.
- Test: `tools/find_card_test.sh` (in CI now): a fake `mount` child runner
  (tools/find_card_child.sh) + sandbox staging; PASSes all six cases:
  mod layout on a local card, on a QNET view, standalone on USB, loose copy,
  `mod/ClusterMap`, and the "card present but empty" case (empty result =
  correctly not-found).
- `mod/custom.sh` uses the same discovery approach (mount table first) for
  its own payload search — it cannot source common.sh before the payload
  exists, so it mirrors the loop.
- Fork repo: the same common.sh is mirrored (fork payload copy), so the
  standalone SWDL card shares this locator.

The card can now live on ANY slot/stick/view name and the scripts still
find it.

## 9. Hard-won debugging signatures (do not rediscover)

- "Screens not visible in GEM" → wrong parent (`screen x greenmenu` — no such screen), or
  LF/CRLF mismatch in `Launcher-sda0.esd`. Fixed by `esd/cm_aa_screens.esd`… **then
  superseded**: manual launcher editing is gone entirely; Addon installs via
  `mod/custom.sh` → `engdefs/`.
- "Read-only file system" mid-install → the remount ladder needed `on -f <full node
  name>` (the GEM console node runs with card on the mmx node). Also probe BEFORE
  touching the unit (`install.sh` writes `NOT INSTALLED … READ-ONLY`).
- "md5 differs / unexpected exports" edits to deploy fail — always re-run
  `tools/check_manifest.sh` after any payload edit (it caught every stale-SHA mistake so
  far).
- `grep` differences between US-script usage and the unit: QNX grep handles binary
  `grep -q` fine on unit‑side; `xargs -d'\n'`, `mktemp`, `sha256sum`, `sort` are CI-side
  only, not available on the unit. Unit side has: `sed`, `awk`, `grep`, `cp -p`,
  `mkdir -p`, arrays not at all. Design every unit script POSIX-only, no `bashisms`.
- Screenshot-attached in-chat images are **not** saved to disk by OpenCode: the two
  driving photos and the GEM screenshots exist only in chat. Don't re-ask the model to
  retrieve them; ask the owner to drop the files (§8 item 3).

### 2026-11-06: fork "detach" settled (user's go-ahead)

Result: mib-cluster-map-generic is ALREADY standalone on GitHub
(`isFork: false`, no fork-network link — the repo was never created as a
GitHub fork; only the code lineage was a fork). Nothing to detach there.
What was done to make the split real and stable:
- Issues enabled on the repo (it had been living without a tracker).
- README/docs/FORK.md lineage wording corrected: "carries MacsInSpace's
  engine", credits + GPL stay; no more "fork of" phrasing.
- The REAL detach risk was two payload homes drifting (Addon `mod/…` vs
  fork `mib-mod/sd-payload/…`). Now enforced: tools/payload_sync.sh
  (drift check + --apply) + a nightly scheduled CI in the fork repo that
  checks against the Addon repo, plus a manual apply path; ci.yml mirrored
  into the fork; find_card locator test added to its CI.

## 10. Decision log (why, in one line each)

| Decision | Reason |
|---|---|
| Addon = M.I.b. mod (no parallel installer / launcher edit) | Owner experience: 2 files + 1 click beats editing an esd by hand |
| Run mod payload from `mod/cluster_map_aa_generic`…  | see repo path `mod/cluster_map_aa_greenmenu/` (name kept from the original fork SD payload convention) |
| Ship upstream v1.1.0 hook + profile_check + libdmdt | Car-tested bits; no cross-compile risk |
| Ship **fork-built** stream-player (v0.4.0); the fork repo is standalone (no GitHub fork link) | The fork features (zoom, arbiter) only exist in fork-built binaries; the fork source is car-proven up to this release line. Built natively, recorded SHA |
| Honesty guards on keep-map/zoom | With upstream player they would silently no-op — misleading |
| `mod/custom.sh` as the only entry | M.I.B.'s documented mod hook, idempotent |
| engdefs/ screen file (not launcher edit) | M.I.B.'s own registration pattern; symlink into engdefs happens at M.I.B. install anyway |
| Sibling-fork repo (this fork repo) | License independence + upstream parity: fork keeps the AA oncology; upstream keeps broad compatibility |

### 2026-11-08 round — the owner's rules ARE the constitution, enforced offline (v0.4.19)

RULE 1 (do not break the unit firmware) — enforced:
- an unarmed install writes NOTHING into gal's supervisor config
  (byte-identical asserted in the sim), replaces no firmware file, never
  edits lsd.sh;
- an armed install keeps the stock stream-player BESIDE the live one
  (.aacluster-original) and the uninstall restores the stock bytes
  exactly (asserted);
- added zip-wide: arm-aware verification tokens (LD_PRELOAD expected only
  after arming).

RULE 2 (do not mess with the GEM) — enforced:
- the install's GEM registration is default-OFF; the GEM's engdefs is
  only touched in the same explicit armed step (HOOK_ARMED marker),
  with verify-stage-rename + .prev;
- z_Launcher-sda0.esd (M.I.B.'s own launcher symlink) is NEVER touched.

NEW CONVENTIONS from the owner:
- ONE diagnostic file on the card: mod/cluster_map_aa_greenmenu/diag.txt,
  written by every run; diag.txt.prev holds the previous bundle. It
  carries: unit/train facts, payload cksums, card + unit view state, arm
  state, engdefs listing (names), installed settings (window/dpi/insets/
  aspect/zoom/full-frame), supervisor env KEY names, hook log tail,
  backup-home record, and the FULL last-run log.
- the GEM console is quiet by default: ~15 curated story lines via
  console_summary.sh; the pages go into diag.txt section 12.

### 2026-11-07 round 2 — the unit-stuck round's answer (v0.4.18)

Symptom root: the FIRST install that ever completed far enough to inject
the hook's LD_PRELOAD into gal's supervisor config — and gal is the
process that draws the GEM ("green menu starting..."), so the hang had no
card-side recovery. The owner demanded a revert without firmware.

Delivered:
- rescue_revert.sh — surgical, idempotent, flash-free, runs from any shell
  (emergency serial console / SSH / GEM); reverts exactly the four write
  targets, with per-step prints and the untouched-original restore path;
- the boot-safety default: installs never arm the hook — arming is an
  explicit second action (card HOOK_ARMED marker, or env
  CLUSTERMAP_HOOK_ARMED=1, or future GEM one-click);
- one-protocol-per-cluster refusal (M.I.B.'s CarPlay Maps VC on the unit);
- verification tokens made arm-aware.

Recovery used on the car: the emergency serial console (mib2-toolbox
rescue: USB-TTL 3.3V at 115200, GND->FBAS-, Tx/Rx crossed) OR dealer ODIS
without flashing; the firmware-SD update is the option of last resort
because it wipes customisations.

### 2026-11-07 round — GEM hang on "Green menu starting..." (v0.4.17)

The owner's car: after running the addon install, the GEM hangs at its
starting screen. The install layer's own write path had NO safety net on
the unit file: `mod/custom.sh` ALWAYS truncated /eso/hmi/engdefs/
cluster-map.esd with whatever the generation produced, so a failed
generation = a broken screen file parsed on EVERY GEM boot = stuck GEM
with no card-only recovery.

Moved to a verified stage-and-rename contract inside custom.sh:
gen -> non-empty + `screen ClusterMap` + no @GREENMENU@ left + every named
script exists on the card -> stage beside the live file -> rename; keep
the previous file as cluster-map.esd.prev; `sync` after the rename; on any
check failure leave the live file alone and STOP before the installer.

Facts to re-verify on the car once the owner un-sticks (card out / card in
discriminator): whether the hang followed our engdefs write or a gal-level
hml change; the screenshot decides which. The .prev copy is the rollback
lever inside our own screen if the GEM lets us run again.

### 2026-11-06 round 3 — the offline gate (venv + pytest car sim) caught the last two single-spelling bugs (v0.4.16)

`tools/venv_test.sh` builds a venv (pytest) and runs `tools/car_sim/` in a
private mount namespace: /mnt,/net,/fs,/sim are tmpfs shadows; `/bin` (the
first PATH entry every script keeps) is an overlay with sim stubs — `mount`
honours QNX's -uw/-ur flag forms and declares CB_MOUNT_TABLE, `on` fails
like a node without cross-node caps. "Read-only view" is expressed the way
the code actually measures it: the view's own probe names
(.clustermap_probe family) fail through EEXIST — read paths keep working.

The suite drives the REAL scripts end to end:
- ladder picks a view that is PROVEN writable through its own spelling
  (FQDN QNET included) and prints the winning form;
- find_card discovers the payload under local, shorthand and FQDN card
  views and still reports a blocked card as a warning, not a stop;
- ensure_write_dir both branches + home-record marker (card / /tmp);
- enable_hook FULL lifecycle with everything else read-only, artifacts
  land ONLY at the FQDN view, config carries the injection, backups get
  recorded and UNINSTALL restores the stock config;
- greenmenu status/verify resolve files across views.

REAL bugs the gate caught and fixed offline:
1. install read the supervisor config through /mnt/system BEFORE any view
   ladder — now system_pick_view resolves the reachable spelling first;
2. the /eso short-alias preload check aborted installs on consoles that
   cannot see /eso — runtime resolves /eso on its own node; the check is
   now a NOTE with the staged path, and Verify/Status validate it after
   the reboot.

### 2026-11-06 round 2 — the owner's QNET complaint was right: view-spelling unification (v0.4.15)

The owner reported the card mounts as `/net/mmx.mibhigh.net/…` while our
scripts still spoke `/net/mmx/…`, and that the card is NOT read-only.
Combined with the earlier console trace, that pins the remaining class:
**the WRITE-side and CHECK-side paths of the app/system partitions were
still single-spelling.** Fixed everywhere, one way:

- `mod/custom.sh` (the GEM screen registration — the step whose silent
  failure made screens "not find files"): engdefs is picked through a
  reachable-AND-writable view probe (/net/mmx.mibhigh.net/mnt/app,
  /net/mmx/mnt/app, /net/rcc/mnt/app, /mnt/app) and always prints which
  spelling won.
- `lib_app_mount.sh`: `APP_VIEWS` ladder incl. the FQDN form;
  `app_probe_view()` guarantees the probe runs through the SAME spelling
  later writes use; `APP_LADDER_FORM` printed by the console;
  `app_pick_view()` for read-only needs.
- `enable_hook.sh`: jsonlint + validator library path resolved via the
  picked view BEFORE the first validation call; app ladder verdict and
  system ladder verdicts printed; system ladder candidates gained /mnt/system
  + FQDN and always re-point TARGET_CONFIG/PERSISTENT_BACKUP to the view
  that accepted the write probe.
- `disable_hook.sh`: same view probing for the restore ladder; jsonlint
  view-resolved.
- `greenmenu/install.sh`, `uninstall.sh`, `status.sh`, `verify.sh`:
  engdefs cleanup, restore manifests, status banners, and the verify
  manifest/path reads are view-aware (`_unitapp`/`_unitsys` helpers;
  verify retries manifest paths across spellings).
- `mod/custom.sh` self-check loops the four app views.
- LEDGER note: a false "card READ-ONLY" report on a writable card means a
  view probe failed, not the card; install no longer stops on it either way.

### 2026-11-06 round — "fix it once and for good" (v0.4.14)
The owner's screenshot disproved two assumptions at once: the card lives
under the QNET view `/net/mmx.mibhigh.net/…` (not only `/net/mmx/…`), and
the payload mirror had been drifting while the drift check printed OK.

1. **The drift check itself was broken.** `diff -u ... | head` pipes the
   real verdict into head's (always-0) exit status, so
   `tools/payload_sync.sh` printed "OK, no drift" even when the fork's
   mirror was stale. Rewritten: un-piped diff, a nested-duplicate map, a
   fork-only whitelist, plus a tar-invocation fix (`--exclude` must come
   BEFORE `-cf - .`). Verified against the genuinely stale mirror: old
   script "OK", new script reports the drift.
2. **One canonical payload, two legitimate entry points.** The fork's M.I.B.
   screens (`esd/scripts/cm_aa_install.sh`) run the nested
   `scripts/enable_hook.sh`; the Addon's greenmenu runs the root copy.
   `payload_sync.sh` now mirrors the Addon's canonical root files onto both
   (`scripts/` copies are governed duplicates), Card-root resolution in
   enable/ disable_hook is content-based (`libgal_hook.so` one level up), so
   both paths behave identically forever.
3. **A read-only card no longer blocks the install.** install.sh's hard
   probe is gone; `ensure_write_dir()` picks the card when writable,
   `/tmp/clustermap_unit` otherwise, records the home in the card's
   `last_install_paths.txt` (or `/tmp/clustermap_last_paths`), written with
   stderr redirected FIRST (redirect-order pitfall: a failed open paints
   the console red if stderr is redirected second). disable_hook reads both
   sources. Functional tests: writable (card wins + card marker written)
   and genuinely-RO card (/tmp fallback + /tmp marker) — both PASS.
4. **M.I.B.'s bundled-tools contract adopted.** `find_card()` prepends the
   card's `apps/sbin` (M.I.B. ships sed/awk/cut/tee/sha1sum/… there;
   its `config/GLOBALS` marks them "not on any unit") with slot-aware +
   QNET-FQDN candidates; CI guard `tools/gem_portable_check.sh` now fails on
   any bare `printf/tr/diff/grep -o`. All GEM-run scripts and custom.sh were
   swept printf/tr/grep -o-free.
5. `common.sh`'s card remount ladder now derives the mount POINT from the
   mount-table line (no hardcoded `/fs/sda0`), extends candidates with
   `/net/mmx.mibhigh.net/fs/sd{a,b}0`, and `mod/custom.sh`'s self-check
   counts ok over both app views (`/mnt/app`, `/net/mmx/mnt/app`) instead of
   printing MISSING lines for a context the console never runs in.

## 11. Safety: what NOT to do

- Do NOT stack M.I.B.'s CarPlay Maps VC omonob payload with this Addon's AA map on one
  unit — one protocol per cluster.
- Do NOT bypass `profiles.conf` + `profile_check` gates on unsupported trains
  (`NOT SUPPORTED` path exists to protect the unit).
- Do NOT enable the DSI tracer for wheel zoom until a car-round has validated the
  current fork player (see §0 Untested row) — the tracer touches the HMI and requires a
  restart.
- MHI2Q (Qualcomm), MIB2 Standard (MST2) and Audi AU37x are **out of scope** for this
  Addon; their sibling projects own their territory (see §7 table).

---

## 12. Round v0.4.20 — the card is never written (2026-11-08)

**Root cause found (owner was right: the card was NOT read-only).** Our own
writes to the FAT card (backups, logs, mkdir probes, staging files) set the
volume's dirty bit; QNX then mounts the card read-only on the next boot. The
addon then reported "READ-ONLY card" and blamed the owner's card. The phantom
was self-inflicted. Established fact: **a payload must never write the card.**

**The rule now stored in the code:**
- The SD card is READ-ONLY MEDIA to this addon. `common.sh` performs no
  remount, no mkdir probe, no staging on the card. The remount ladder and the
  "PROBLEM: the SD card is READ-ONLY" message are deleted.
- Install work home = `/tmp/clustermap_unit` (backups + marker); hook log =
  `/tmp/gal_dualscreen.log` (the unit-wide convention status/diag already
  read). The persistent config recovery copy an uninstall needs is
  `<live config>.gal-dualscreen.original` beside the config on the unit.
- `mod/custom.sh` runs `diag_collect.sh` from an EXIT trap (`trap … 0`), so
  EVERY exit produces the bundle. `/tmp/clustermap_diag/diag.txt` is
  guaranteed; `<payload>/diag.txt` is a single best-effort copy for the owner.
  The bundle includes the script's own narration, so an early stop says WHY.
- Shipped card folder renamed to `mod/cluster_aa` (short, 8.3-friendly);
  locators prefer it and still accept `mod/cluster_map_aa_greenmenu`,
  `ClusterMap`, etc. Arming accepts `HOOK_ARMED` or `ARMNOW.TXT`.
- Unarmed console verdicts are truthful: `DONE`, `FAILED`,
  `Staged only (not armed)`, or `Map already live … nothing changed`.
  `CLUSTERMAP_*` internals are filtered out of the console.
- Bug fixed: screen generation is fully inside the `GEM_ARMED` gate. It
  previously ran unarmed with an empty engdefs path and could write
  `/cluster-map.esd`.

**Offline proof:** 31 tests green (`tools/venv_test.sh`), including: card
never written (`test_write_homes.py`), early-failure diag + reason,
no-payload diag, already-live verdict, `mod/cluster_aa` discovery. Also green:
`check_manifest`, `check_gem_esd`, `gem_portable_check`, `find_card_test`.

---

## 13. Round v0.4.21 — one click: install + arm + screen + diag (2026-11-08)

**Owner ask:** "can you not automate 3/4?" — the arm step and the diag fetch
must not be manual. Answer delivered as a release-level contract:

- **The ZIP is armed; the REPOSITORY is not.** `tools/build_release.sh`
  creates `mod/cluster_aa/HOOK_ARMED` in the shipped tree only, and now
  FAILS the build if that marker is missing from the zip or if the repo's
  payload carries it. Consequences: the owner's single "Run /mod/custom.sh"
  = validated screen + armed hook + player backup + diag; and every offline
  test keeps exercising the unarmed path, so a test can never arm a unit.
  `tools/check_release_build.sh` asserts the contract on a real build and is
  part of `tools/venv_test.sh`.
- **GEM `2b. Make the map LIVE`** (`menus.sh arm` → `CLUSTERMAP_HOOK_ARMED=1
  install.sh`): the explicit arm action is now reachable from the GEM, so the
  stage-only mode (delete `HOOK_ARMED` on the card) needs no card edit and no
  PC. Arming stays a deliberate action; nothing arms silently.
- **Ordering rule (safety):** screen validation + write happen BEFORE the
  installer runs; any screen failure exits first, so a broken engdefs file
  can never coexist with a live hook. Unchanged: `.prev`, persistent
  supervisor backup, rescue_revert.sh.
- **BUG FOUND AND FIXED (v0.4.19/v0.4.20 shipped it): every ClusterMap GEM
  entry did nothing.** `menus.sh` began with `. "$HERE/lib_app_mount.sh"`;
  that file lives in `scripts/`, not `greenmenu/`, so the unreadable source
  line terminated the dispatcher (dash exits rc 2) before any verb ran. The
  dispatcher now loads the real path and a missing copy cannot kill the menu.
  New regression test parses the screen file, asserts every `menus.sh <verb>`
  has a case, and that the template and the pre-built `.esd` agree on the
  entry set — the class of bug (screen calls a verb the dispatcher lacks) is
  now impossible to ship.
- Console paths in `menus.sh` no longer name the old payload folder.

**Offline proof:** 34 tests green; `check_manifest`, `check_gem_esd`,
`gem_portable_check`, `find_card_test`, `check_release_build` green.

**Residual risk, recorded honestly:** an armed install puts
`libgal_hook.so` into gal's supervisor config in the same run that
registers the screen. If the hook itself is bad on this unit, the next boot
hangs the GEM (gal draws it) and only the serial console / firmware SD can
recover — that is the exact incident from 2026-11-07. The owner chose
one-click; the mitigations are the validated screen-before-hook ordering,
`.prev`, the persistent config backup, `rescue_revert.sh`, and the fact that
the diag bundle is written BEFORE the reboot, so evidence survives even a
hung GEM.
