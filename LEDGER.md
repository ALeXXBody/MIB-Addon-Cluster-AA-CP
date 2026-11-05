# LEDGER — M.I.B. Addon: Cluster AA/CP

> **Purpose:** every verified fact, decision and signature from building and
> debugging this Addon on the real car, in one file. Read this before doing
> any new work on the project. Update it as findings land; do not re-derive
> what is already written here. Last updated: 2026-11-05 (owner: ALeXXBody;
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

## 10. Decision log (why, in one line each)

| Decision | Reason |
|---|---|
| Addon = M.I.b. mod (no parallel installer / launcher edit) | Owner experience: 2 files + 1 click beats editing an esd by hand |
| Run mod payload from `mod/cluster_map_aa_generic`…  | see repo path `mod/cluster_map_aa_greenmenu/` (name kept from the original fork SD payload convention) |
| Ship upstream v1.1.0 hook + profile_check + libdmdt | Car-tested bits; no cross-compile risk |
| Ship **fork-built** stream-player (v0.4.0) | The fork features (zoom, arbiter) only exist in fork-built binaries; the fork source is car-proven up to this release line. Built natively, recorded SHA |
| Honesty guards on keep-map/zoom | With upstream player they would silently no-op — misleading |
| `mod/custom.sh` as the only entry | M.I.B.'s documented mod hook, idempotent |
| engdefs/ screen file (not launcher edit) | M.I.B.'s own registration pattern; symlink into engdefs happens at M.I.B. install anyway |
| Sibling-fork repo (this fork repo) | License independence + upstream parity: fork keeps the AA oncology; upstream keeps broad compatibility |

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
