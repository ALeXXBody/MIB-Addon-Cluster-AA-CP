# M.I.B. integration matrix — mib-cluster-map (M.I.B. Addon edit)

| Feature | M.I.B. alone | mib-cluster-map (fork) | Combined |
|---|---|---|---|
| **AA map in VC** | ❌ M.I.B. has no AA→VC engine | ✅ (this mod, via `libgal_hook.so` + `stream-player` from chopinwong01's hook via mib-cluster-map upstream) | ✅ M.I.B. is base toolbox; our mod adds only the AA→VC path |
| **CarPlay map in VC** | ✅ (bundled `carplay_maps_vc/omonob` payload for CarPlay **only**) | ✅ | ⚠️ install **only one of the two** on any unit |
| AA / CarPlay / MirrorLink coding (`0xC0020054` bits 7.7 / 8.0 / 8.5) | ✅ (`apps/carp -a`) | ✅ (same bit layout, same block address) | ✅ idempotent |
| IFS-ROOT-Stage2 patch (CP / FEC / EL) | ✅ (M.I.B. flash option) | ❌ (fork doesn't patch the IFS) | ✅ complementary |
| NavActiveIgnore | shipped by M.I.B.'s toolbox & by the fork | ✅ same jar name both sides; M.I.B. GEM toggles it without a conflict | ✅ |
| GEM screens | M.I.B.'s own set | fork adds 1 extra top-level screen | ✅ |
| VIM, sport displays, Ambient lighting | ✅ M.I.B.-only | ❌ fork doesn't do those | ✅ complementary |

## Install matrix

| | Our AA map (this mod) | M.I.B.'s CarPlay maps | Fork's CarPlay map (not used here) |
|---|---|---|---|
| This M.I.B. mod | ✅ required | ❌ conflicts | ❌ conflicts |

## Files written to the unit by this mod

Same list the fork's enable_hook.sh touches (see upstream docs):

- `/mnt/app/eso/lib/gal_dualscreen/libgal_hook.so`
- `/mnt/app/eso/lib/gal_dualscreen/gal_dualscreen.conf`
- `/mnt/app/navigation/stream-player`
- `/mnt/system/etc/eso/production/smartphone_integrator.json` (preload entry only)
- `/mnt/app/eso/hmi/engdefs/` (green-menu screen if the owner wants the fork's GEM UI)
- `/mnt/app/eso/hmi/lsd/lsd.sh` (`NavActiveIgnore.jar` + turn-arrows jar lines)
- `/mnt/system/etc/pf*.conf` (CarPlay port open — fork-independent)

M.I.B.'s CarPlay Maps VC payload uses a **different** install area
(`/mnt/app/carplaymaps/`), so both stay separate unless you stack them.

## Fail-safe

Same as the fork's own safety rule: never remove the SD card during install.
If M.I.B. is already installed, rebooting after this mod is enough —
**do not** re-flash IFS-ROOT stage-2 from M.I.B. when the fork is added.
