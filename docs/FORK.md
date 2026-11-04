# This fork: "MHI2 Cluster Map — Tiguan Edition"

**Upstream:** [MacsInSpace/mib-cluster-map](https://github.com/MacsInSpace/mib-cluster-map)
(GPL-3.0, by MacsInSpace, built on [chopinwong01/mhi2-android-auto-video-vc](https://github.com/chopinwong01/mhi2-android-auto-video-vc),
[andrewleech/VcMOSTRenderMqb](https://github.com/andrewleech/VcMOSTRenderMqb),
[harman-f/mhi2_altscreen_carplay](https://github.com/harman-f/mhi2_altscreen_carplay),
[olli991's MQB Coding MIB2 Toolbox](https://github.com/olli991/mib-std2-pq-zr-toolbox) and others).

This fork carries the same GPL‑3.0 license. Every original author's copyright
and credit stands; this file only describes what the fork changes. Do not
strip the upstream credits from the README when you publish.

## Development fork identity

| | |
|---|---|
| Purpose | Tiguan AD1 (MQB) use of phone maps on the Virtual Cockpit, plus a few robustness features useful to every supported car |
| Target tested base | `MHI2_ER_VWG13_P4521[_1]` / `K4525`, Tiguan AD1 with the 10.x‑inch AID (`3G0920790E` family) |
| License | GPL‑3.0, identical to upstream (upstream carries the GPL‑3.0-only file) |
| Changes | see `CHANGELOG-fork.md` |

## What the fork adds (vs upstream main today)

1. **`GAL_KEEP_MAP` cockpit source arbiter** — upstream maintains that the
   unit's own HMI can switch the cluster back to the stock map while the
   phone streams (upstream issues #19/#43, CarPlay). With
   `GAL_KEEP_MAP=phone` the player probes the cockpit every few seconds
   (`dmdt gs`) and re‑asserts its own context when the stock map came back,
   bounded by `GAL_KEEP_INTERVAL_S` and `GAL_KEEP_MAX` per session. Off by
   default (`auto` = exact upstream behaviour); ships with a green-menu
   toggle.
2. **`GAL_PLAYER_ZOOM_E4` + `/tmp/stream-player.zoom`** — crop‑and‑enlarge
   of the phone's picture around its centre (10000 = 1.0, 13500 = zoom 1.35).
   Zoom costs no decode time: the player only reads a smaller texture
   rectangle. The runtime file takes effect without a session restart.
3. **`Verify installed files`** green-menu action — recomputes `cksum` over
   everything the installer deploys and compares it against a manifest the
   installer leaves on the unit, so a broken install can be told apart from
   a settings issue without pulling the SD card.
4. **Keep-map and verify wired into the green menu** screen
   (`ClusterMap`), consistent with the existing sharper‑map switch.
5. **Tiguan documentation** (`docs/Tiguan.md`): what to measure on the car,
   what the profile rows mean, and how the verified P4521 family fits the
   Tiguan AD1 AID10.

## What the fork deliberately does not change

- Everything upstream already got right: the ACK pacing, the second-sink
  injection into `gal`, the MIS‑safe `smartphone_integrator.json` editing
  ("Rule of 10"), the profiles-as-data layout, the safe fallbacks.
- Lanes / distance / ETA in the cluster requires the Java‑side jar work
  upstream describes as not started; the hook already translates 0x8006 /
  0x8007 → 0x8004 / 0x8005 only.

## How to build the fork

Exactly as upstream (`build_local.sh`, Docker + the QNX
`qnx65-armv7-toolchain`), no changes needed: the fork touches only the
player (`player/opengl_gpu.cc`), the installer (`swdl/update_run.sh`), the
green-menu screen (`greenmenu/cluster-map.esd`) and green-menu scripts.
Nothing in `src/` (the `gal` hook) was modified, so the profile table's
fingerprints still match all the cars upstream already supports.

## How to publish

```sh
git remote add origin git@github.com:<your-account>/<your-fork>.git
git push -u origin tiguan-fork
```

Keep the `LICENSE` (GPL‑3.0) and this file, and note the fork's name in the
README header of your published fork after the upstream author's own
heading so the credits stay obvious for anyone reading it.
