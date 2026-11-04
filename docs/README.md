# M.I.B. integration — install mib-cluster-map-tiguan from M.I.B. GEM

## TL;DR

If M.I.B. is already running in your Tiguan, you can skip the fork's own
SD-card update path and drive the **Android Auto → Virtual Cockpit** hook
(`libgal_hook.so` + `stream-player`) from M.I.B.'s own GEM, as a *mod*,
exactly like M.I.B.'s bundled CarPlay Maps VC payload.

Do **not** use this fork's own metainfo2 SD-card update on that unit — use
**one** installer. Install the *AA→VC hook* through M.I.B., and install
**CarPlay Maps VC** (the cluster CarPlay map) through M.I.B.'s bundled
omonob payload if you want CarPlay too. Installing both the fork's
CarPlay-in-VC and M.I.B.'s CarPlay-in-VC on the same unit breaks both
(the same supervisor / jar names / install paths).

## What this folder is

| Path | What it is |
|---|---|
| `esd/scripts/cm_aa_status.sh` | M.I.B. GEM screen #1 — status of the fork's AA→VC hook |
| `esd/scripts/cm_aa_install.sh` | M.I.B. GEM screen #2 — runs the fork's `enable_hook.sh` |
| `esd/scripts/cm_aa_uninstall.sh` | M.I.B. GEM screen #3 — runs the fork's `disable_hook.sh` |
| `esd/scripts/cm_aa_collect.sh` | M.I.B. GEM screen #4 — runs the fork's `collect_logs.sh` |
| `esd/Launcher-sda0.esd.append.md` | The screen-definition block to splice into your M.I.B. SD card's `Launcher-sda0.esd` |
| `install_payload.sh` | Copy helper for the fork's payloads |

## What to bring from the fork

These are **not** shipped here (you build them yourself or grab them from
the fork's release>per-MU build — each unit has its own `gal` and the *IFS
offsets* differ per train; the fork matches them with `tools/find_profile.py`,
never with a shared binary):

```
mod/cluster_map_aa_greenmenu/                       <- fork's own SD card layout
├── scripts/
│   ├── enable_hook.sh
│   ├── disable_hook.sh
│   ├── hook_status.sh
│   ├── collect_logs.sh
│   ├── lib_unit.sh  lib_app_mount.sh  lib_keep_settings.sh
│   ├── lib_cluster_frame.sh  lib_resolve_hook_log.sh  lsd_jar.sh
│   ├── gal_dualscreen.default.conf
│   └── ...
├── libgal_hook.so                 compiled (per-MU)
├── stream-player                  compiled (per-MU)
├── profiles.conf
├── gal_dualscreen.conf
├── dmdtgo                         (optional zoom helper) 
└── greenmenu/                     the fork's own GEM scripts (optional lookups)
```

Plus from upstream, only if M.I.B.'s option 7 hasn't been run yet:
`apps/NavActiveIgnore.jar`.

## How to install (once)

```sh
# 1. M.I.B. is already installed and GEM enabled in your Tiguan.
# 2. Copy the fork's payload to your M.I.B. SD card, under the M.I.B.
#    "mod" convention, so M.I.B. can see it across the same SD mount:
#        mod/
#        ├── carplay_maps_vc/      … M.I.B. ships this already
#        └── cluster_map_aa_greenmenu/   <- fork payload, new
#
# 3. Splice the screen block from esd/Launcher-sda0.esd.append.md into
#    M.I.B.'s Launcher-sda0.esd on the SD card (one insert — no unit write).
#
# 4. Reboot the unit into M.I.B. GEM and use the four new screens:
#        Main → Cluster Map (Tiguan fork) — Android Auto on VC
```

The GEM screens write the fork's own files to the unit (`/mnt/app/eso/lib/gal_dualscreen/`,
`/mnt/app/navigation/stream-player`, `smartphone_integrator.json`), run
`carp -a` via M.I.B. for AA-persistence, and reboot with the fork's own
"Reboot Unit" path. They do NOT replace M.I.B.'s own GEM, and they don't
install M.I.B.'s own CarPlay Maps VC payload.

## How it stays compatible with M.I.B. and the ecosystem

1. **M.I.B.'s own GEM stays intact** — the fork's GEM screen is a separate top-level GEM entry (`Main → Cluster Map (Tiguan fork)`). M.I.B.'s bundled GEM (`M.I.B.` / `CarPlay` / `Maps in VC`) is untouched.
2. **M.I.B.'s CarPlay Maps VC install stays untouched** — our screens only write to `/mnt/app/eso/lib/gal_dualscreen/` and `/mnt/app/navigation/`, never to M.I.B.'s CarPlay payload at `/mnt/app/carplaymaps/`.
3. **Persistence bit `0xC0020054` is shared** — but the *values* written are the same for both (AA and CarPlay both go to `1`). No conflict; the fork's install path leaves AA already activated (or uses M.I.B.'s `carp -a`).
4. **M.I.B.'s firmware-train MHB check is simply skipped** — the fork's script has its own `scripts/lib_unit.sh` for the Tiguan AID10 family and doesn't depend on M.I.B.'s `MIBCHECK`.
5. **M.I.B.'s `IFS-ROOT-Stage2` patch is not touched** — the fork's hook lives at `/mnt/app/eso/lib/gal_dualscreen/`, not in the boot image, and needs no IFS patch. Put the fork together with M.I.B.'s IFS stage-2 patch only if you run both together — they complement, not replace. Make sure M.I.B. is installed first (M.I.B. flasher writes the IFS, reboots, then our installer runs).

## Notes on correctness

- `enable_hook.sh` from the fork only needs `LD_PRELOAD` enabled, a valid `gal` on the unit (MHI2 VW family) and the fork's own `profiles.conf` to match the unit's `gal` (MHI2_ER_VWG13_P4521[_1], P4174, K4525 or upstream's US versions). No Green Engineering Menu bit is written by us.
- M.I.B.'s `GEM=1` survives in the shell; the fork's scripts defensively unset `GEM` and `LD_PRELOAD` — this works on the car and doesn't regress M.I.B.'s own state.
- On failure, the fork's scripts print to `/net/mmx/fs/sda0/ClusterMap/update_result.txt`, not to the M.I.B. log; the M.I.B. log still shows the M.I.B. side.
- The `dmdtgo` and `rundmdt` helpers from `tests/emul/` are **not** required for this path; they are only for an AA-map inspection. M.I.B.'s own `CarPlay Maps VC` is enough for AA "map in VC"— *no, that's CarPlay only*. The fork is what actually does **Android Auto on VC**.
- Keep the fork's `profiles.conf` matching your Tiguan's variant (AID10 `790`) — the `P4521` profile already matches MIH2_ER_VWG13 with a 10.25″ AID10 cluster. `V2.1 rc.7` is still experimental, so `2.0.1 beta + Tiguan profile` is the rock-stable path that is already car-verified upstream.

## Summary — no-car/reversals centre

| | M.I.B. | mib-cluster-map-tiguan |
|---|---|---|
| CarPlay-in-VC | ✅ bundled omonob payload (MU1367 790/791, V70 1.1.0)        | ✅ (harman-f hook, source) — **install only one of these two** |
| **Android Auto-in-VC** | ❌                                                          | ✅ (libgal_hook.so, chopinwong01 hook) |
| AA / CarPlay / ML activation | ✅                                                       | ✅ (even writes fewer bits than M.I.B. option 7) |
| IFS stage 2 patch / FEC / CP | ✅ (if you flash a pre-patched IFS)                      | ❌ (install via SWDL is independent) |
| GEM screens | ✅ M.I.B.'s own (CarPlay, navigation, backup, ambient …)     | ✅ one extra screen (`Cluster Map (Tiguan fork)`) — do **not** install both CarPlay-in-VC packages |

So: keep M.I.B. as your **general toolbox**, and use this fork as the
**only source of AA-on-VC** for MHI2 Tiguan.
