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
| Car | VW Tiguan AD1 (`5NA035020D`), `MHI2_ER_VWG13_P4521`, 10.25" AID, related doc: `docs/car-test-notes.md` |
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
| Addon = M.I.B. mod (no parallel installer / launcher edit) | Two files + one click beat editing an esd by hand |
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

The car diag showed the card mounts as `/net/mmx.mibhigh.net/…` while our
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

**Car-round feedback:** automate the arm step and the diag fetch. Answered as a release-level contract:

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

---

## 14. Round v0.4.22 — why there was NO diag.txt on the card (2026-11-08)

**Report:** "there is no diag.txt file on the card after the addon install…
aa is showing in cluster". Install worked (map live), card copy did not.

**Root cause chain, by construction:**
1. v0.4.21's collector delivered the card copy as `cp ... 2>/dev/null`
   inside the exit trap — every failure mode invisible;
2. the unit mounts a FAT card **read-only** when the dirty bit is set
   (unclean eject on a PC -- our own 2026 diagnostic, round ~12), so an
   owner who copied freely and pulled the card gets a read-only card whose
   read side is fine: installs work, downloads work, the map runs;
3. the GEM console then said NOTHING about the card at all (the card line
   only printed on success), so "no diag.txt" was indistinguishable from
   "the run never wrote the bundle".

**Fixes (no symptom patches):**
- `/tmp` stays authoritative, and the card copy is now a **real operation
  with a contract**: probe each spelling of the payload folder with an
  actual 0-byte write (only one may accept writes on a QNET unit), copy via
  redirection (no `cp` dependency), checksum-verify, `sync`, and narrate the
  outcome either way. On refusal the console prints `NOT WRITTEN - the card
  is read-only to the unit`, the PC fix (proper eject / chkdsk), and the
  six tuning facts so a screen photo replaces the file for tuning round.
- **Found while testing:** POSIX shells (dash) EXIT when a special builtin's
  redirection fails, so `: > probe` would kill the whole delivery script
  exactly in the read-only case — the one case it exists for. All three
  `: >` redirections (custom.sh console log, bundle scratch, card probe) are
  now subshell-isolated. This class of bug is why "the foul fall must be
  tested on the map we don't control": the sim emulated read-only card views
  and caught it immediately.
- Tests: read-only card → spoken aloud + facts printed + no bogus claim;
  blocked first spelling → falls through to the writable spelling and NAMES
  it; happy path → the copy line is always there.

**Instruction to the owner in the release HOW-TO:** if the screen says
NOT WRITTEN, put the card in a PC and eject it properly (or chkdsk /f X:)
once, then use GEM -> ClusterMap -> 10/11. Save logs — the file appears.

---

## 15. Round v0.4.23 — the car says "Script not found" on every entry (2026-11-08)

**Report:** after the card refresh, every ClusterMap entry answers
"Script not found"; earlier in the round, also "still no diag.txt".

**Analysis (construction, not excuses):** the live GEM screen on the unit
carries the WHOLE script path of the era that installed it. We renamed the
payload folder in v0.4.20 (mod/cluster_map_aa_greenmenu → mod/cluster_aa,
the owner's own "short folder" suggestion) but the rename made every
pre-rename screen dead the moment the old folder left the card. The screen
only regenerates on an ARMED custom.sh run, so a card update alone does not
heal it. And with dead buttons there is also no new diag run — which is
why "still no diag.txt" was the same single failure.

**Fixes:**
- **The payload path is frozen for good:** `mod/cluster_aa` is the one
  canonical location from v0.4.23 onwards; build asserts, docs say so.
- The shipped pre-built `greenmenu/cluster-map.esd` now names
  `/net/mmx/fs/sda0/mod/cluster_aa/...` (the zip's own reality), not the
  fork folder from a past era.
- **VERSION stamp:** every release carries `mod/cluster_aa/VERSION`; every
  run (custom.sh AND every GEM verb) prints `payload version/`"payload on
  the card:"` — the card refresh question is answered by the unit itself.
- **Second diag card home:** when the payload folder refuses the copy, the
  card ROOT is probed the same honest way (`diag.txt` at the root);
  success is named, refusal is spoken with the tuning facts.
- install.md gets the "Script not found" section (2 clicks, no PC): rerun
  Run /mod/custom.sh - the screen re-anchors to the LIVE card path.

**The owner's unit fact, now the contract:** the unit mounts the SD card
READ-ONLY at boot and a card write needs ONE explicit `mount -uw` first.
v0.4.21-22 never remounted (add-on treated the card as permanently RO
media - my overreaction to the phantom-RO incident), which is why the diag
copy could fail UNLESS the card happened to be RW. v0.4.23: the diag copy
probes first, remounts RW when refused (`mount -uw` on the winning view),
writes, checksum-verifies, `sync`s, then rejoins RO (`mount -ur`) so the RW
window is exactly the one copy. The console narrates the remount and, if
even that fails, says NOT WRITTEN with the tuning facts.

---

## 16. Round v0.4.24 — the diag round: what the file proved, and the flat home

**The diag reached the card and was accepted** — v0.4.23's RW-remount card
copy works on the owner's car (the bundle's "payload version: v0.4.23"
proves the round trip: install in car → copy on card → sent by the owner).

**What the bundle establishes (unit facts, not guesses):**
- train `MHI2_ER_VWG13_P4521`, app/system views readable+RW reachable via
  /mnt/* AND /net/mmx.mibhigh.net/mnt/*; jsonlint present; ESO alive;
- GEM screen registered in engdefs (the "Script not found" class ended at
  v0.4.23's re-anchor + frozen folder name);
- hook installed and preloaded into gal; PERSISTENT supervisor backup
  present beside the config; hook session ran ~6 min with clean
  own.ack/black-box streams and no aborts in the tail;
- real installed numbers for the picture tuning:
  `GAL_PLAYER_WINDOW=1010x376`, `GAL_SECONDARY_DPI=125`,
  `GAL_SECONDARY_INSETS=40,40,127,127`, `GAL_SECONDARY_MARGINS=0x182`,
  `GAL_SECONDARY_PIXEL_ASPECT_RATIO_E4=10000`, `CLUSTERMAP_FULL_FRAME=0`.
- The install verb of that run FAILED EARLY: `mkdir -p
  /tmp/clustermap_unit/backups` -> "Function not implemented" (ENOSYS),
  while FILE creation inside /tmp works (the hook's own log). This unit's
  /tmp does not support subdirectories. Nothing harmful happened because
  the install is idempotent (the hook was already live from an earlier
  armed install); but every restage/settings run would keep failing here.

**Fix (v0.4.24):** ensure_write_dir is DIR-FIRST with a measured FLAT
fallback — when /tmp disallows subdirectories the home becomes /tmp
itself, backups land as flat files, the marker records HOME_MODE=flat,
and the uninstaller resolves the original in BOTH homes. No folds, no
code without a car-fact behind it.

---

## 17. Round v0.4.25 — "Script not found": TWO true causes this round (2026-11-08)

**Report:** still every ClusterMap button answers "Script not found", even
with v0.4.23/24 installed (the owner's diag from the same build proves the
screen IS registered in engdefs and the hook is live).

**Root cause, finally the true one:** the GEM screen we generate names the
card spelling THAT CONSOLE saw (`/fs/sda0/...`, the view custom.sh used for
its own reads). The GENERATOR is right from its own context — the CONSUMER
is not: the GEM process (which parses engdefs and EXECUTES screen scripts)
runs on the node whose slot-1 card is `/net/mmx/fs/sda0`, the exact prefix
M.I.B.'s own screens have always used. A screen full of `/fs/sda0` paths
compiles and installs; every press then fails inside the GEM's own exec.

**The regression that hid this:** the generated screen's path validation
only asserted paths that already start with `/net/` — so a `/fs/sda0`
screen skipped the check completely and shipped broken. Two unit-truths
bundled into the fix:

1. **The spelling the GEM executes is the contract**: generation prefers
   `/net/mmx/fs/sda0/<payload>/greenmenu/` (verified reachable from the
   console), falls back to the founderview spelling only when that path is
   not reachable. The pre-built screen keeps its (correct) GEM spelling
   byte-exact in that case.
2. **engdefs resolution**: the ladder now probes with a FILE WRITE
   (`: >` inside a subshell — the same "units that refuse mkdir" truth from
   round 16), creates missing dirs per candidate, and never invents an
   alias (the owner diag's stray "cp: cannot create ...: No such file or
   directory" was a fallback alias with no engdefs on it).

**Instrumentation so the next round shows the cause itself:** the diag
gains section 6b - it reads the LIVE engdefs screen file and gives, PER
ENTRY, ok/MISSING for the path the GEM would execute. A dead menu is now
self-explaining.

Gate: 42 tests (new: GEM spelling used when reachable; fallback keeps the
console view; diag 6b lists ok/MISSING per entry).

**The format bombshell: M.I.B.'s pages never let the frame pass arguments to scripts.** M.I.B.'s own menus are written with **bare paths** in every `value` (verified against Launcher-sda0.esd line by line), because the unit runs the entire quoted string as a script name. Calling `menus.sh arm` makes the system look for a
```
value   sys 1 0x0100 "…/menus.sh arm"
```
that is not found. This format, which looked "natural", still doesn't even work even with perfect paths.

**Final fix, in M.I.B. convention: `greenmenu/gem/` — one tiny wrapper file per menu entry**
(`status.sh`, `install.sh`, `arm.sh`, `full_frame_on.sh` … `portfull.sh` — 24 of them, 4 lines each),
which call the same dispatcher `menus.sh` (one target script for all, partial card copies cannot break the switches),
and the screen itself references **bare paths** `@GREENMENU@gem/<name>.sh` — like any M.I.B. page.
Template and built page regenerated; new tests: every screen entry = an existing file in the card WITHOUT arguments,
each wrapper leads to a known dispatcher switch, the GEM-spelling is the one used when it is reachable,
and diag section 6b gives ok/MISSING for each entry in the LIVE page — a dead menu explains itself.

Gate: 42 tests.

---

## 18. Round v0.4.26 — the switch scripts' source line + full_frame + diag for every entry

**Car observation (v0.4.25 in the car):**
- "Sharper map" searched for `full_frame.sh`; the card carries
  `full_frame_on.sh` / `full_frame_off.sh` — the dispatcher named a file
  that does not exist. Fixed: the full_frame verb takes the argument into
  its dispatch (on/off -> the real scripts).
- "Cluster remote" printed `.: .../lib_app[...]` and nothing else — the
  SOURCE bug class from round 13 again: five switch scripts
  (cluster_remote, navstrip, card_clear, keep_map, zoom) sourced
  `greenmenu/lib_app_mount.sh`, which never exists there (the shared lib
  is `<payload>/scripts/lib_app_mount.sh`); a failing `.` ABORTS the
  shell, so the switch did nothing and said almost nothing. All five now
  source through the guarded, existing path.

Car question answered as a feature: does diag.txt record these errors? It now must.** The direct verbs (zoom, navstrip, cardclear,
remote, keep_map, verify, porting, portfull, full_frame on/off, tbt) ran
their child script straight into the GEM console with no capture, so photo
was the only evidence. Every verb now runs through the same runner:
full log captured, curated console, the diag bundle rebuilt, and the card
copy attempted + narrated on every entry. The console photo above is
therefore the LAST time a screenshot is the evidence chain.

Gate: 45 tests (new: dispatcher scripts all exist; wrappers resolve to
existing files; per-verb file names audited against the card).

---

## 19. Round v0.4.27 — the remount refusal becomes measurable (owner diag, pre-update)

The owner's diag (v0.4.25 card) is half a goldmine, and it ends the
"silence" of THIS failure class:
- **the card copy works** and the GEM screen is fully resolved: section
  6b lists every entry `ok` (24/24) for the live screen;
- **the flat install home works** on this unit (`HOME_MODE=flat`);
- **the map itself is alive and translating**: nav stream shows real road
  data ("towards First Ave"), the player spawns, focus/stream/ack all
  connected, `kombi.ready` swap at 41 s — the deliverable runs clean.
- The scan found the last silent refusal: the REINSTALL's
  `Cannot remount the app partition read-write` printed only the FORMS
  tried, not what the mount actually SAID. M.I.B.'s own toolbox remounts
  app as `mount -uw /net/mmx/mnt/app` (plain form, per cswdl/most/
  udevice/tones), ours is a superset ladder - still refuses on that boot
  without a word.

**v0.4.27:** every remount attempt records the unit's own stderr + exit
code (`app remount: mount -uw /mnt/app -> rc=...: <the mount's message>`),
both in the console and the diag; the winner is announced as
`app: read-write via '...'`; and the failure message states plainly that
the LIVE map is not touched, only updates are blocked. Offline suite now
includes a guard that a refusal with no stderr text is still a refusal
(the regression that would have pretended success).

Gate: 45 tests.

---

## 20. Round v0.4.28 — every entry ends with the outcome and the next step

**Car-round feedback:** end every run with a done line and the next instructions.

Delivered as a contract, not a per-script patch: one new file,
`greenmenu/run_verdict.sh`, ends EVERY entry's console with
- `== DONE` (or `== STOPPED` when the run log carries an error verdict),
- `Next: <exactly what to do next>` - reboot + cockpit-switch for
  install/arm/uninstall/tbt/full_frame, "leave the menu, it is live"
  for the switches, "take the card home and send mod/cluster_aa/diag.txt"
  for Save logs, "send me the bundle" for porting, "nothing required"
  for status/verify.

Run through the capturing runner (round 18), the verdict tail now lands
after the "payload on the card" and "card copy" lines - the console always
closes with the facts. Gate: 46 tests (the tail is asserted per verb).

---

## 21. Round v0.4.29 — the picture is tuned: the owner's photo is the evidence

The owner sent the cluster photo with FULL FRAME on:

  window 1010x376, DPI 125, insets 40,40,127,127,
  FULL_FRAME=1, PAR=1.6117, MARGINS=0x0.

Photo reads correct: straight circles, crisp street labels ("towards First
Ave", "First Ave", "Porthill Bank") - no visible stretch, HUD (P/position/speed)
sits on the black band, no overlay on map content. The tuned geometry is
Pinned in the shipped card config (gal_dualscreen.conf), so a fresh card
re-install lands on THIS look instead of reverting to the band view;
deleting the three lines returns to stock geometry. In-car switches still
win over anything (re-press = new values recorded on the unit).

The remaining "zoom" feel is the PHONE's map zoom (AA streams what Google
Maps/Waze shows), not the add-on's geometry - the GEM Zoom entries are for
fine correction only.

---

## 22. Round v0.4.30 — "scripts not working anymore... showing ..." 

**Report from the car:** after the v0.4.28/29 card refresh, presses answer
with just "..." - the GEM's empty-output marker. Nothing on that screen
has ever been our text, so our chain ran but produced NOTHING that the
story filter matched - child died early or the whole runner's prints fell
over on the unit's shell. The diag bundle (written on EVERY run since
v0.4.26) is therefore the deciding artifact; section 11/12 carry the full
run log in both cases.

**Two defences shipped NOW (correct regardless of which one is the
breaker):**
- run_verdict detects failures with plain `grep -q` probes instead of
  `grep -qE` alternation - the ONE construct in the chain that a unit
  grep may reject;
- Save logs is back to a DIRECT path (savelogs.sh prints its own `Done:`
  line) - the evidence chain must never depend on the mechanism being
  debugged.

**Also shipped as the fallback the owner can use while reporting: the
v0.4.27 zip is still downloadable; that card state is the last measured
working menu.** The dashboard of the add-on itself (hook, map) runs from
the unit and is unaffected by card script states.

---

## 23. Round v0.4.31 — the GEM 4.12st console bug identified (owner photo)

The owner's photo settled the "...": the error is in the unit's own GEM -
`de.audi.gem.` stack, `ScreenRenderer().enterConsoleScreen()`,
`IllegalThreadStateException: Thread is already started`, on GEM 4.12st -
the console screen BREAKS on re-entry, shows "...", and throws BEFORE our
script is called. Consequences, measured against our own rules:

- a run at that point leaves NO diag from us - there was no process to
  capture (this is GEM's renderer, not our chain);
- the earlier "Sharper map ON"/"Cluster remote ON" stage changes in the
  bundles PROVE the presses ran when the console was healthy - the
  display bug masked them afterwards;
- the stack also shows the entry path came through a LONG press
  (handleLongPress -> TouchController.touchGestureReceived -> ...).

**v0.4.31 defence - floor every press:** the console now carries the
MINIMUM per press (bundle paths, `== DONE / Next: ...`, and the ERROR
lines only on failure). Every extra render line is work for a broken
renderer. The full story remains in diag.txt sections 11/12, which the
bundle keeps on the card for every run; Save logs stays a direct path.

The defect itself is GEM's (fork v3.8.0 shell), the trigger avoidable by
short clicks / Back between presses; nothing in our payload can repair
the renderer, and M.I.B. has no defence for it either.

---

## 24. Round v0.4.32 — proof-of-execution line for the "..." console

Presses still show `...` in the car (ScreenRenderer crash pages
gone after re-entering GEM, but presses still print nothing readable).
Two explanations remain, and from the seat they look identical:
1. our chain never executes on the press (the GEM drops the exec), or
2. it executes, and the 4.12st renderer hides everything we print.

v0.4.32 makes those two distinguishable by eye: every press's first line
is now execution-proof text -
`ClusterMap <verb> ran / payload on card: vX.Y.Z` - which OUR chain is
the only thing that can print. If a press shows just `...`: our code did
not run. If it shows `ClusterMap zoom ran / payload on card: v0.4.32` +
`== DONE / Next: ...`: it ran and only the renderer hid the rest.
Either way the card's diag.txt (sections 11/12, written every run) is the
authoritative measurement read of a press.

Gate: 47 tests.

---

## 25. Round v0.5.0 — the FULL audit: every file, every path, every flow

**Sweep across the whole payload (61 shell scripts, 173 file references, every
source/spelling/mount/save path):**

1. **rescue_revert.sh still searched only the pre-rename folder**
   (`mod/cluster_map_aa_greenmenu`) - THE hung-GEM recovery tool would not
   have found the card under the released layout. Fixed: both layouts.
2. **greenmenu/uninstall.sh removed the menu screen through a `mkdir`
   probe** - this unit REFUSES mkdir (rounds 16/18); uninstall would have
   reported "Menu screen not found" and left the GEM screen behind.
   Fixed: the file-write probe ladder, identical to the installer's.
3. **status.sh carried the one remaining `grep -E`** in the chain; on the
   unit's grep that pattern silently prints nothing. Converted to plain
   `-e` probes (focus/player/stream events).
4. **The keep-settings feature was silently dead since the day it
   shipped:** the installer gates 'carry the owner's changed lines over'
   on `scripts/gal_dualscreen.default.conf` - WHICH WAS NEVER SHIPPED.
   The owner's tune would have been reset on every card re-install
   despite the README's promise. Fixed: the snapshot now ships, and the
   card config carries the explicit `CLUSTERMAP_KEEP_SETTINGS=1` switch.
5. custom.sh's install self-check now also enumerates the GEM wrappers,
   the shared lib and the defaults snapshot (an incomplete card copy is
   named before it costs a car round).
6. Re-audited and CONFIRMED sound: 173 payload file references resolve
   (the missing-file noise was alternating fallbacks and external M.I.B.
   payload paths, all guarded); every dot-source in the payload is
   guarded against the shell-abort class; the card-write rules hold
   (no writes outside the diag copy + owner-invoked Save logs); the
   mount/unmount pairs balance; the diag bundle covers every entry; the
   release contract still asserts the one-click zip.

---

## 26. Round v0.5.1 — the deeper script audit: WHY the switches showed "..."



1. **console_summary.sh had blank lines INSIDE its sed argument list.**
   `sh -n` accepts them (a blank line is valid shell), but at runtime the
   line after the blank became a NEW command - `-e: not found` - and
   every curated story pattern after it silently STOPPED working. That
   regression shipped with the v0.4.28 story blocks; it is exactly when
   presses started answering "..." in the car. Fixed; the offline gate
   now runs the whole curated-story chain against every pattern (the
   runtime bar, not shell -n) - 51 tests.
2. **Bigger: switches hard-wired ONE remount form.** cluster_remote,
   navstrip, card_clear, zoom, keep_map and scripts/full_frame did
   `mount -uw "$APP_MOUNT" ... || exit` - the exact form the owner's
   earlier diag recorded refusing ("Cannot remount the app partition
   read-write"), so on that car cluster remote/navstrip/etc. could do
   nothing at all. All now run the shared ladder (`app_mount_rw` from
   lib_app_mount.sh) and write through `$APP_RW` - the alias that took
   the remount - with the winner announced
   (`app: read-write via '...'`) and all-refusals named per form in the
   bundle. Regression: a press must WRITE through the working spelling,
   must announce the winner, and must report == STOPPED (never fake
   done) when every form is refused.
3. The curated story patterns missed the switches' real output lines
   ("Cluster remote (...)", "Turn info strip:", "Turn-card clear:",
   "Keep map:" spelt both ways) - even a healthy run would have shown
   nothing for them. Now all in, matched by the new runtime-curation
   test.

**Also re-verified:** the switch scripts keep writing only to the unit
settings copy; Save logs remains a direct path; the release contract and
manifest stay green; the payload affected files: 6 switch scripts,
console_summary, run_verdict (exit code), menus (floor).

---

## 27. Round v0.5.2 — the car caught a TRUNCATED run_verdict.sh ("no closing quote")

Press photo: `gem/../run_verdict.sh[49]: no closing quote`. The verdict
script shipped TRUNCATED since the proof-of-execution edit (v0.4.32): the
case block ends 48 lines in, mid-branch, no `esac` - a parse error the
offline gate repeatedly missed because the content tests only matched
early-line snippets while the syntax sweep was not re-pointed at the
actual file state each round. Press feedback collapsed to the error-story
only ("-- the run's ERROR lines:"), which still worked (the new ladder
announced every refusal for the first time: "Cannot remount ... every
form failed:", the unit's own verdict histories from `APP_LADDER_ERRORS`).

Fixes:
- run_verdict.sh REWRITTEN complete: one echoed line per branch, no
  nested constructs, both outcomes, the exit contract (1 on a failing
  log, 0 otherwise) spelled out;
- the gate test rewritten whole: every dispatcher verb owns a verdict
  branch, both outcome lines exist, the case closes, both exits exist,
  and the live subprocess pair (failing log -> rc 1, clean log -> rc 0)
  is exercised; 50 tests;
- the "app: read-write via '...'"-ladder announcement lands in the FULL
  story (bundle), not the floored console - the owner's own press photo
  proves the refusals reached the seat.

---

## 28. Round v0.5.3 — the owner's diag: mounts were SUCCEEDING, the probe was the liars'

**The bundle that settles every outstanding switch, remount and install
failure of this thread (line for line):**

```
mount -uw /mnt/app                      -> rc=0: no message
mount -uw /net/mmx.mibhigh.net/mnt/app  -> rc=0: no message
mount -uw /net/mmx/mnt/app              -> rc=0: no message
on -f mmx mount -uw /mnt/app            -> rc=0: no message
on -f rcc mount -uw /mnt/app            -> rc=1: ldd:FATAL ... (unrelated tool)
```

FOUR REMOUNTS SUCCEEDED - and the switch still reported "every form
failed". The refuser was not the unit: it was `app_probe_view()`, which
probed with **mkdir+rmdir** - the exact syscall this unit REFUSES
(`Function not implemented`, ENOSYS - proven in the round-16 diag). Every
ladder that matters (app, system in enable_hook, restore in
disable_hook) carried the same fatal probe. Consequences of one probe:

- every switch "did nothing" on every good boot that used a non-default
  view form (the "cluster remote is not doing anything" entire round);
- installs aborted at "app partition: NO view accepted writes"/
  "Cannot remount the app partition read-write";
- uninstall/uninstall-only decks "Cannot remount" noises.

**Fix:** all three ladders now probe with a FILE write
(`( : > probe )`, subshell-guarded) - the operation every working
remount grants on every qnx/boot layout observed. The offline gate's
read-only emulation switched from "pre-existing file" to "directory at
the probe name" (EISDIR blocks `: >`) so the tests measure what the unit
measures. 50 tests, full release gate green.

---

## 29. Round v0.5.4 — "map the position further": the inset lever, on the GEM

Car-round feedback: the map content position in the cluster window is not where the eye wants it.

The layout levers the unit actually offers (hook keys, verified in the
binary's own strings): window size, symmetric band margins (no offset),
zoom (centre-crop), and the FOUR content insets
(GAL_SECONDARY_INSETS top,bottom,left,right in the 800x480 frame) - the
phone's safe area, which moves the content box (turn card, labels, speed
limit) INSIDE the map window. That is the position lever; the window
origin itself belongs to the GEM/kombi window 33 (not touchable from a
card honestly).

v0.5.4 ships Position presets as first-class GEM entries, same contract
as every switch (shared remount ladder, write through the winning alias,
POSIX-safe rewrite through a rename, story in the bundle, DONE/Next
tail, exit contract):
- Content UP / DOWN - moves the content box a step up/down (8 px, repeat as wanted)
- Content WIDER / NARROWER - box width steps
- back to the shipped look - restores 40,40,127,127
Every value lands at the NEXT phone session; a photo + Save logs locks
the chosen values for the porting map. 52 tests (position: content up
writes the insets through a working view; standard restores the shipped
90... shipped values).

Writing shipped through all shells' parsing: position.sh done single-level
substitutions only (the nested-backtick round-27 class again pasted by
this author's own tooling; caught by the 52-test gate before release).

---

## 30. Round v0.5.5 — "the texture is not clear like a low-res conversion"

**What the car-facts pin down (diag + hook binary):**
- The phone streams the cluster at **800x480 coded** - the hook binds the
  cluster sink to the primary's own resolution table (a hard fork
  constraint; the shipped config keys GAL_SECONDARY_WIDTH/HEIGHT accept
  only 800/480 - anything else is overridden back with a
  config.resolution log line).
- Your window is 1010x376, so the map is always up-scaled (~1.26x), and
  in full frame squeezed 480->376 stretched to 1010: the visible
  "low-resolution conversion" feel is that resample, not a defect in
  this card side. TRUE hardware sharpness would need the sink patched
  to a higher-coded resolution (the hook's own
  `secondary.output_patch from=.. to=.. success` machinery proves a
  patch CAN land silicon-side - a topic for a fork round, not a card).
- The IDR cadence (~60 s between key frames, from the hook log) makes
  text wander slightly softer near the end of each gap - phone-side
  GOP, not ours.

**Found and fixed on the card side (v0.5.5):** your unit carries the
Turn-card TOP preset as the expert override
(`GAL_SECONDARY_UI_CONFIG_HEX=5a041202083c`). That key REPLACES the
insets AND theme entirely - the Position presets therefore do nothing
until the override is removed. From now on every Position press clears
the override (theme keeps its own key). Sim test added.


---

## 31. Round v0.6.0 - "improve the binaries": the hi-res cluster stream, rebuilt hook

The binaries are ours to change, and the sharpness ceiling sits inside them - so they were improved.

**What v0.6.0 changes inside libgal_hook.so** (the fork's own source,
rebuilt with the recorded QNX 6.5 ARMv7 toolchain natively on this host
- the unpacked image root from BUILD_LOCALLY.md):
- new hook capability, opt-in via GAL_SECONDARY_HIRESEN=1 (a plain line
  in gal_dualscreen.conf; loads via the hook's own conf loader, so the
  GEM can switch it without touching the supervisor);
- the cluster sink NOW ALSO declares the phone's higher cluster
  resolution (AA codec enum 2, 1280x720) BESIDE the 800x480 entry -
  ADDITION, not replacement, so a phone that rejects enum 2 leaves the
  historical stream untouched;
- the declared insets scale to the coded frame (1.6 x, 1.5 y, clamped)
  so the safe area keeps its on-screen meaning; margins 0; PAR=10000
  (the DPU side only letterboxes at the window);
- hard refusal with a line in the log when the expert UiConfig hex is
  present (unscaled 800-frame insets would replace the safe area);
- default OFF: without the key this build behaves byte-identically to
  v0.5.x (the config-resolution pin, decoder depth, 400x400 protection
  - all unchanged);
- the delivered stream at enum 2 is decoded by our own ffmpeg-mini
  player, which samples whatever arrives into the window - DOWN instead
  of UP this time - the sharpness the car round asked for.

**On the GEM (this card):** ClusterMap gains Hi-res trial
declare-1280x720 / Hi-res trial OFF (hiresen.sh writes/removes the key;
the switch is inert for an older hook). **On the wire, honestly:**
higher-coded frames need more bitrate than the phone's default cluster
stream; if the encoder starves, configure the phone or remove the key
and reboot.

---

## 32. Round v0.6.1 - the IDR pump: the sharpener between the phone's own 60 s key frames

**What it does:** a steady streaming session re-keys only at the phone's
own ~60 s GOP; text drifts softer toward each gap (the owner's last
"texture is not clear" feeling). The pump deliberately bounces the
secondary's video focus for ~1.5 s every N seconds - the controller's own
loss path (mode 2, player KEPT, back to grant), so the phone re-opens the
stream with a fresh IDR. Net effect: every gap between sharp frames
stays well below the phone's own cadence, at the cost of a brief blink
per respin (at the 10-20 fps cap that is 1-2 frames).

**The rules it lives under (insides of focus_ctl.c):**
- opt-in only: GAL_IDR_PUMP=SECONDS (>= 10, <= 300; anything else logs
  off); OFF is byte-identical to v0.6.0;
- the pump fires ONLY behind the controller's own health gate
  (FC_HEALTHY_MS + recent ACK): it cannot fire on a sick session, while
  the mailbox holds an intent, or during teardown;
- every grant resets the countdown, so the pump never overlaps its own
  recovery; the log carries `event=idr.pump action=respin` +
  `event=focus.loss reason=idr_pump player=kept`;
- the player is never killed in the pump (stop_player = 0), so no backoff
  and no re-spawn: the on-car cost is only the blink.

---

## 33. Round v0.6.2 - the end-to-end audit caught the screen wiring before the car did

The press-chain audit tool (tools/audit_wiring.sh, additive: every new
switch joins the audit) proved its worth immediately. Findings:

1. **v0.6.1 shipped the Hi-res/Sharpness-pump GEM SWITCHES without their
   SCREEN ENTRIES** (the wrappers existed, menus/verdict ran, but the
   engdefs screen had no buttons to press). Fixed: all four entries added
   to template + built screens (33 wrappers, 33 entries, 1:1).
2. **One stale prefix line** (`position_standard` kept the placeholder
   value in the built screen): every entry's spelling is now checked
   against the same release layout predicate as check_gem_esd.
3. `set -eu`-shell gotchas in the audit itself fixed; the verdict live
   pair is now asserted with explicit exit codes.

The gate now verifies END-TO-END for every aspect that a press touches:
33 wrapper->dispatcher->child circuits, 11 GEM-writable keys each
consumed by a shipped binary, the verdict chain live, manifest fresh,
release contract green, the capture chain present, and every script
parse-clean. 53 sim tests + this audit = the shipping bar.

---

## 34. Round v0.6.3 - the ETA card gets its own pose presets

Owner: "modify the green card (eta, directions) so it can be reshaped and
placed in a better position."

The green card's SHAPE is the phone's turn banner layout inside Android
Auto's UiConfig content inset - the same field family the shipped
Turn-card presets use. v0.6.3 extends that family to all four edges
(bottom/left/right did not exist) and adds a fifth (wider top) for the
strips the owner asked about:

- ETA card: TOP strip (the shipped pose, 5a041202083c)
- ETA card: BOTTOM strip (5a041202103c) - NEW
- ETA card: LEFT column (5a041202183c) - NEW
- ETA card: RIGHT column (5a041202203c) - NEW
- ETA card: broad TOP strip (5a041202084c, 76 px) - NEW
- ETA card: OFF (removes the hex; the hook re-derives from the plain
  insets, so the Position presets drive again)

Same contract as every switch: shared remount ladder, single-edge hex
(write through the winning view; the hook resolves its conf through the
same first-success order), bundle story, DONE/Next tail, and a helpful
"the hex overrides the plain insets" line. Sim tests cover each pose's
hex landing and the OFF reset; the wiring audit goes green with 38
wrappers = 38 screen entries.

---

## 35. Round — the APPLY guide, computed from the real tag diff

**Owner ask:** every release must say in its description whether a
reinstall is needed, and what to do - some releases need it, others don't.

- New tool: tools/release_guide.sh PREV TAG - computes the "APPLY"
  section from the REAL file diff between the two tags: card update
  needed? (any mod/** change), one more GEM click? (only when a file the
  installer copies onto the unit changed: the hook .so, the settings
  copy, the screen template and the installer-side helpers), reboot,
  and the standing evidence loop (Save logs + diag.txt + photo).
- tools/build_release.sh appends the computed guide to the zipped
  HOW-TO-INSTALL.txt (the doc the owner has in hand at install time).
- .github/workflows/release.yml now assembles the release body =
  the tag commit's message + the computed APPLY section
  (and the tool's dash/refine pass verified the verdict for every
  historical release; each GitHub release was updated accordingly:
  skip-rules for script-only rounds, yes-rules for the hook/screen
  rounds).
- The refine pass itself caught a shell case-splitting bug in the
  tool's first cut: unquoted case patterns split on the IFS and
  everything matched the wildcard branch, making v0.6.0 (which rebuilt
  libgal_hook.so) report "skip" - the literal alternation replaced it
  and the verdicts were re-computed and re-published.

---

## 36. Round v0.6.4 - the car diag found the probe's last hiding place: the ROOT

Owner diag (0473c096) + photos: hi-res argu-press acts again (the pressed
ETA/positions wrote), but the STEERING WHEEL press did nothing this
boot and the install stopped again: the ladder's own per-form output
named FOUR remounts returning rc=0 ... and then "every form failed".

The truth this time: on this unit the app view's ROOT refuses direct
file writes while SUBDIRECTORY writes work - the same boot's engdefs
write succeeded through the FQDN alias the root probe refused. The
probe now writes AT THE WORK TARGET FIRST
(`$1/eso/lib/gal_dualscreen/.clustermap_rw_probe`, because that is where
every app write in this payload goes: the settings copy, the hook, the
backups), with the view-root probe still there as the fallback.

The wheel control: the unit's settings copy no longer carries
GAL_CLUSTER_REMOTE (this boot's switches wrote other lines over an
install whose engine copy wasn't refreshed?): the same press, after the
fixed probe lands, re-applies it (ClusterMap -> Cluster remote ON).
The hook is v0.6.1's binary and consumes it at the next gal start.

---

## 37. Round v0.7.0 - the in-cluster menu (no GEM trip while driving)

**Owner ask:** "recreate the GEM menu visible in the cluster when AA is
activated, to activate/deactivate functions without going in GEM."

**Delivered, using both halves the fork already had (the cluster-remote
wheel key injection + the player's overlay renderer):**

- **Hook (rebuilt, build id v0.7.0):** with `GAL_CLUSTER_MENU=1` (a
  plain line in gal_dualscreen.conf) the hook routes the wheel into the
  player's menu instead of acting itself: SHORT OK opens the menu (and
  applies the chosen row as "sel"), the ROTARY navigates (up/down
  forwarded), LONG OK keeps the strip toggle (owner's muscle memory).
  The gestures reach the player as one-line events in
  /tmp/stream-player.menu.
- **Player (rebuilt):** player/menu.h: a 6-row overlay over the map,
  drawn luma-only (the same 5x7 font and backing bar as the strip; no
  extra GL state), rows with their live values, chosen row indented and
  brighter, auto-close after 8 s of inactivity:
    Zoom (live via /tmp/stream-player.zoom)
    Strip (live via /tmp/stream-player.navstrip)
    Card (LIVE-cycle of the ETA-card pose via /tmp/gal_uiconfig -
          the hook's ui-config sender puts it on the wire immediately)
    Pump (live via /tmp/gal_idr_pump - the focus controller polls it
          1x/s while healthy)
    Hi-res (next phone session via /tmp/gal_hires; the hook reads it
          when it builds the session)
    Exit
- **Runtime rereads** so the menu rows are honest: the pump period polls
  the file per respin decision; Hi-res is read per session build (next
  session; no gal restart needed).
- **GEM:** ClusterMap gains Cluster menu ON/OFF (the same audited write
  path, verdict tail, copy-the-key flow). OFF = exactly the previous
  wheel behaviour (short OK cycles the ETA card).
- The menu is a library-level feature: inert for an older hook
  (nothing reads the key) and requires the cluster-remote channel
  (v0.6.4's Cluster remote ON press) for the wheel input.

**On the build:** both binaries rebuilt with the recorded toolchain
(hook v0.7.0, stream-player relinked against the existing ffmpeg-mini
static libs); the wheel channel itself was ALREADY proven on this car
(the route through 0x8001 that the owner's earlier presses used).

---

## 38. Round v0.7.1 - "can the reboot be avoided?" the honest re-tier

**Owner ask:** avoid the reboot; change settings without it. The
re-timing analysis ends with: a full unit reboot is needed ONLY for the
install/uninstall of the hook itself (the LD_PRELOAD chain is read by
the supervisor once) and for a GEM-screen button change (the file with
the buttons is parsed by GEM when GEM renders it). EVERYTHING ELSE has a
live path:

- **live on the wire** (the fork's ui-config sender):
  Position presets and the ETA-card pose presets now ALSO write
  /tmp/gal_uiconfig, which the hook turns into an immediate
  UpdateUiConfigRequest to the phone - v0.7.1: the written insets and
  the poses apply while the map runs (the phone accepts them on the
  wire; on software that drops the update it lands at the next session),
- **live locally** (files the fork processes poll): Cluster menu
  (the hook reads /tmp/gal_cluster_menu at every wheel gesture - the
  very next press enters or leaves the menu), Sharpness pump
  (the focus controller polls the period file 1x/s while the session
  is healthy), Zoom/Strip (already live),
- **next phone session** (unplug/replug the USB, or cycle phone AA):
  Hi-res 720 (the hook reads the file when it builds the next
  session) and sharper-map/margins/geometry (they sit inside the
  AddConfiguration the phone takes at session setup),
- **full reboot**: only the installer/uninstaller and GEM screen button
  changes (the wheel/one-click flow, since the older pipes for the
  hook/site copy are read by the supervisor once at gal start).

GEM texts corrected everywhere the "reboot" wording had crept in
(install-screen labels and Next: instructions now name phone-session
tiers). No new GEM entries; four switch scripts + the hook binary
(v0.7.1 build) changed.

---

## 39. Round - the deep full-system audit (v0.7.1, the "every connection" pass)

**What was verified, line by line and byte by byte:**

1. **The GEM screen ↔ the payload (1:1):**
   40 wrappers on the built screen = 40 on the template = 40 wrapper
   files on the card; every entry is a bare script path (the M.I.B.
   format the GEM resolves).
2. **Every press circuit:** wrapper → dispatcher verb → handler script
   → (ladder (app_mount_rw)) → write through the winning alias →
   verified → story in the diag bundle → verdict tail with the correct
   timing tier. All 40 resolve; nothing references a missing file.
3. **Every key a GEM switch writes has a consumer in the shipped
   binaries:**
   - `GAL_CLUSTER_MENU` (hook: live wheel routing)
   - `GAL_IDR_PUMP` (hook: pump period + the /tmp file)
   - `GAL_SECONDARY_HIRESEN` (hook: hi-res declaration)
   - `GAL_CLUSTER_REMOTE` (hook: wheel bindings)
   - `GAL_PLAYER_WINDOW/ZOOM_E4/KEEP_MAP` (player)
   - `GAL_SECONDARY_DPI/INSETS/MARGINS/PIXEL_ASPECT_RATIO_E4`
     (hook: sink + wire)
   - `CLUSTERMAP_FULL_FRAME` (shell-side geometry + hook PAR)
   Each was then re-shell-audited down to the wire path
   (UpdateUiConfigRequest via /tmp/gal_uiconfig included).
4. **The LIVE tier is real, not a claim:**
   - the hook's menu poll accepts /tmp/gal_cluster_menu ("0"/"1") and
     flips on the very next wheel gesture (the wire routing itself
     traced: gesture → cluster_remote_event → menu event file →
     player's overlay);
   - the pump period file /tmp/gal_idr_pump is polled 1x/s while the
     session is healthy;
   - /tmp/gal_hires is read at every build_secondary_sink — a menu
     toggle lands at the next phone session (no gal restart);
   - /tmp/gal_uiconfig catches Position/ETA-card writes and turns
     into an immediate UpdateUiConfigRequest.
   (all five paths reread in the source and confirmed as strings in
   the SHIPPED binary — the release's own bytes, pulled from the tag
   and byte-compared with both payload copies: identical.)
5. **The release byte-consistency check:** the v0.7.1 zip's
   libgal_hook.so and stream-player are byte-identical to the two
   payload copies in the repo and the fork; the shipped hook carries
   every runtime file path (menu/pump/hires/wire) and both mode keys.
6. **The static gates:** manifest, screen parse, portability,
   find_card, release contract (armed zipped / unarmed repo), all
   scripts parse; 56 sim tests; the harness wiring (runner →
   diag_collect → card truth → verdict tail) verified in the source.

**where known work is still open (unchanged by this audit):**
- the car round to confirm the wheel channel end-to-end on this unit
  (Cluster remote ON press was re-issued in v0.6.4);
- the Hi-res + pump sharpness car trial (photo pair) for pinning;
- GEM 4.12st's own console-screen re-entry bug (display-side, not ours).

---

## 40. Round v0.7.2 - the wheel trace: the car round needs ONE diagnostic

**Owner: "steering wheel commands are still not working."** The wheel
path has FOUR gates, and the last diag showed at least one of them open
(section 7 lacked GAL_CLUSTER_REMOTE - the key the switch writes had not
landed when the wheel was tried). So ask the car the ONE question this
diagnostic answers:

- **Wheel trace** (GEM: "Wheel trace: ON"): every input indication is
  logged at INFO (code/action/rotary delta) - the hook's trace reads
  /tmp/gal_remote_trace at each incoming event, so it arms without a
  restart; the persisted GAL_REMOTE_TRACE key survives boots too.
- Cluster remote binding goes LIVE as well (v0.7.2 hook reads
  /tmp/gal_remote at each event; the switch still writes the persisted
  GAL_CLUSTER_REMOTE key).
- The hook then answers in the diag: either gestures ARRIVE (and the
  trace printed their code/action/delta - a code other than the
  Skoda-class OK=23 is now visible and mapped by GAL_CLUSTER_KEYCODES
  if needed) or gestures DO NOT ARRIVE at the cluster input channel
  (a VW Tiguan AD1 routing fact -римен we meet only with the evidence).

**The car round (v0.7.2) is the wheel round:**
1. card merge (mod/ v0.7.2) + one Run /mod/custom.sh click (re-stages
   the hook) + reboot once;
2. GEM -> ClusterMap -> Wheel trace ON -> press the wheel (short OK,
   long OK, rotary both directions) -> Save logs;
3. send diag.txt. It carries per-gesture: event=remote.trace ... parse
   rot=.. code=.. action=.. delta=.. at INFO - and the run summary
   shows if events arrive at all (no trace lines = the wheel's presses
   are not reaching the cluster input channel: the unit-side answer
   then comes from M.I.B.'s/VW-side notes, not from more guessing);

---

## 41. Round v0.7.3 - the sharper-map press never ran since v0.5.1: the CONF-before-ladder bug

**Owner diag (the "can't read :" + "The settings copy names no cluster
map window" lines): the sharper-map press DIED inside the switch.**
scripts/full_frame.sh read the WINDOW through $CONF - assigned only
AFTER the remount ladder - so the variable was EMPTY at the read: every
sharper-map press since the v0.5.1 ladder patch answered "settings copy
names no cluster map window". Fixed: the pre-ladder reads (WINDOW, the
FRAME_CONF_MARK check, NOW) use CONF_READ, the write stays CONF (the
ladder's winning alias). The probe's refusal reason now lands in the
ladder's record per form ("write probe at <path>: <errno>").
Sim: the sharper-map regression + the probe-reason record; 58 tests.

---

## 42. Round - consolidation: the fork repository retired

The working mirror `github.com/ALeXXBody/mib-cluster-map-generic` is
retired; **this Addon repository is the single source of truth** from
now on: the payload (`mod/cluster_aa`), the rebuilt binaries
(`libgal_hook.so` v0.7.x, `stream-player` with the menu), the fork's
sources under the toolchain, and the whole audit trail (LEDGER rounds
1-41) already live here. A full git bundle of the fork (4.5 MB,
`--all` branches/history) was taken before the removal and kept
locally, so nothing is unrecoverable.

Deleting the remote repository needs the `delete_repo` OAuth scope,
which the current token does not carry - the deletion is therefore
completed by the owner (one `gh auth refresh -h github.com -s
delete_repo` + `gh repo delete ALeXXBody/mib-cluster-map-generic
--yes`, or the web UI's repository Settings -> Danger Zone).
