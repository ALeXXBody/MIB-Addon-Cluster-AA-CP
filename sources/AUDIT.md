# Audit — fork commit `1816ba9` + follow-up fixes (2026-11-04)

Scope: every file the fork added or changed vs upstream `MacsInSpace/mib-cluster-map`
@ `decb7eb` (`git diff decb7eb..HEAD`), plus the shell scripts it calls and the
fixture/gitignore surface that could leak data.

Reviewed with a source-read of each touched file (`player/opengl_gpu.cc`,
`greenmenu/GEM/{verify,keep_map}.sh`, `swdl/update_run.sh`, `tests/emul/**`,
README/CHANGELOG/FORK/Tiguan docs), plus static syntax checks (`sh -n` /
`g++ -fsyntax-only`).

---

## BLOCKER (was real, fixed in this pass)

### B1 — Real vehicle E2P data committed to a public repo
`tests/emul/fixtures/eeprom.txt` was a **real DSI E2P dump of a unit**
(part numbers, JT-hardware codes, build dates, variant strings). It was
committed as a "fixture" even though `tests/emul/README.md` says real firmware
must stay out. Fixed by: `git rm --cached` + `rm` + new `.gitignore` rules
(`tests/emul/fixtures/eeprom.txt`, `*.fec`, similar patterns).
**Residual risk:** the file is still in the git *history* (commit
`1816ba9`). If you want to publish the repository *and* keep that dump
private, rewrite the fork branch (`git rebase`/`filter-repo`) before sharing,
or accept the data is public. It is a *Skoda* unit dump, but it carries VIN-
adjacent part-number strings, so treat it as personal-ish data by choice.

## MAJOR (was real, fixed in this pass)

### M1 — `verify.sh` manifest line-format mismatch
`swdl/update_run.sh` writes `printf '%s %s\n' "$f" "$csum"` where `$csum` is
`cksum` output minus the path = *two* whitespace tokens (`<crc> <size>`),
so each manifest line is `path <crc> <size>` (3 tokens) — but the original
`verify.sh` did `read -r tag file want` (3 tokens, using the wrong
interleaving for `case)`), which always reported CHANGED.
Fixed: `verify.sh` now reads `read -r FILEGIVEN WANTSUM WANTSZ`, re-computes
`cksum` output with `awk '{print $1, $2}'`, and compares the *combined*
`"<crc> <size>"` string instead of just one token.

### M2 — keep-map arbiter race vs. the final stock-map restore
The arbiter thread was **detached** at spawn (`pthread_detach`). On shutdown,
`execute_final_commands()` flipped `g_switchClosed = true`, joined the switch
thread, ran `dmdt_pair(g_dmdtRestore, …)` — but a detached arbiter could
still be in its 250 ms sleep and fire one *re-assert* after the restore,
putting the phone map back on the cluster exactly once and leaving the unit
in the wrong context.
Fixed: `g_arbiterStop` volatile flag + a **non-detached** `g_arbiterThread`
handle; `execute_final_commands` now sets the stop flag and joins the
arbiter before its final restore. Re-asserts can no longer land after the
stock map is restored.
**Also:** the arbiter's sleep loop uses `usleep(250000)` × 4 = 1 s per
iteration set; because it's not detached it can delay shutdown for up to
~1 s. Acceptable.

### M3 — `update_run.sh` false-negative for AA-only installs
The jar-list block flipped `manifest_ok=0` when a jar was *absent*. On an
Android-Auto-only unit there is no `CarPlayNavigationPatch.jar`, so the
installer would have printed "Verify manifest: partially written" with no
```cksum unavailable```. Fixed: only a **read/cksum failure on a file that
exists** stamps `manifest_ok=0`; a missing jar is, as upstream says itself,
an expected state.

## MINOR (fixed in this pass)

- **Licence wording mismatch** — `LICENSE` is upstream's GPL-3.0-*only* file,
  but `docs/FORK.md`/`CHANGELOG-fork.md` said "GPL-3.0-or-later". Fixed to
  "GPL-3.0" with an explicit note that the upstream LICENSE file is the
  `GPL-3.0-only` text.
- **README typo** "motived" → "targeted" (an old draft wording).
- **verify.sh tool detection** — `command -v cksum` inside a POSIX sh on QNX
  6.5 is sketchy; replaced with a portable loop over known paths
  (`/usr/bin/cksum /bin/cksum /mnt/app/armle/usr/bin/cksum /opt/bin/cksum cksum`).
- **`keep_map.sh`** — POSIX-safe rewrite through `$CONF.new` and `mv` kept,
  `app_mount_finish` trap intact. No change.
- `README.md` still says "motived" in the intro, now fixed.

## MINOR — accepted / for owners to decide

- **`GAL_KEEP_MAP=stock` value**: documented in the source comment
  ("auto/off/stock: upstream behaviour") but **not** exposed in
  `greenmenu/GEM/keep_map.sh` or the docs. It behaves as "auto". A future
  owner-facing UI should expose it or drop it from the docs.
- **`g_keepMap[12]`** is bounded: `strlen(val) < sizeof(g_keepMap)`; a
  longer conf value is truncated to 11 chars — no overflow, no overflow
  risk, but the *value* silently truncates. Consider logging a warning if
  truncation happens.
- **Upstream's `profile check` gate**: profiles.conf has `TESTED 0` entries
  and the fork added none: unchanged. All Tiguan values are the upstream
  standard `VW 800x480 DPI 138 INSETS 52,82,127,127 CONTEXT 70`.
- **`tests/emul/run_dmdt.sh`, `run_gal.sh`** still exist with stale content
  from an earlier probe (the accepted runner is `run_unit_dmdt.sh`). Either
  delete the stale ones or add a comment. Not a blocker.

## INFO / for future work

- `keep_map_stock_seen()` shells out to `/eso/bin/apps/dmdt gs` — on a real
  unit that process needs a running displaymanager (it is one there), which
  is present when the player runs, so this is fine on the car. On QEMU it
  prints the framework.json-abort we saw; the parser *ignores* garbage
  output by construction (it only matches the restore-displayable id as a
  standalone decimal word).
- The `verify_manifest.txt` should also include the **persistence keys**
  touched by `dmdt` (the IQ items upstream validates) so the green menu can
  compare those, not just files. Suggested for a future iteration.
- `player/opengl_gpu.cc` grew to ~2.4k lines with the fork changes; a follow-up
  refactor should split the fork additions into `player/keep_map_arbiter.c(c)`
  and `player/zoom.c(c)` upstream-style units.
- The **IIFE**-shaped `player/opengl_gpu.cc` uses `g_zoomE4` without a
  mutex; it's written once from the config parse and re-read in the render
  loop from the runtime file (same thread), so no race — but a future zoom
  control file writer should have a shared `pthread_mutex_t` if it's ever
  written from another thread.

## Verified-good (no change needed)

- `swdl/update_run.sh` top-of-install guards for ` vitamins (`MODE=collect`,
  `MODE=uninstall`) unchanged and still safe.
- `greenmenu/GEM/keep_map.sh` writes via `$CONF` + `mv` — POSIX-safe and
  doesn't need `sed -i` (not available on QNX 6.5's /bin/sh).
- `greenmenu/GEM/*.sh` — all use the upstream `common.sh` convention and
  don't break the GEM directory.
- `.gitignore` keeps `tests/emul/root/`, `*.log`, `*.fec`, `*.bin`, `.venv/`
  out of git.
- `player/opengl_gpu.cc` compiles clean (`g++ -fsyntax-only` with the GLFW
  path) and `sh -n` clean on every script.
- No private data anywhere else the repo tracks: `git ls-files
  tests/emul` now shows only `README.md`, `run_dmdt.sh`, `run_gal.sh`,
  `run_unit_dmdt.sh`, `qnxifs-unit.build`, and
  `fixtures/dmdt_gs_placeholder.md`.

---

## How to reproduce the checks

```sh
sh -n greenmenu/GEM/*.sh scripts/*.sh swdl/*.sh     # none should fail
g++ -fsyntax-only player/opengl_gpu.cc              # ok
cc -I src tests/nav_translate_test.c src/nav_translate.c -o /tmp/navtest && /tmp/navtest
tests/profile_check_test.sh <your-unpacked-gal-path>
git diff decb7eb..HEAD --stat                       # fork-only changes
git log --oneline decb7eb..HEAD
```

— audit by the fork's maintainer, 2026-11-04.
