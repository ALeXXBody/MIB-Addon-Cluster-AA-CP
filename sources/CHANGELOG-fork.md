# Changelog — this fork

Forked from **MacsInSpace/mib-cluster-map** (upstream main, GPL-3.0 (the LICENSE file is GPL-3.0-only, as upstream ships it)):
`decb7eb Install keeps the owner's changed settings`

## This fork: 1.0.0-fork.1 (2026-11)

- **`GAL_KEEP_MAP` cockpit source arbiter** (player): re-asserts the phone
  stream's map onto the cluster when the stock map has been switched back
  in, bounded per session. Off by default; green-menu toggle "Keep map".
  Targets the switch-back race in upstream #19/#43.
- **`GAL_PLAYER_ZOOM_E4` / `/tmp/stream-player.zoom`**: crop-and-enlarge on
  the player, around the frame centre. Composes with the margin crop; no
  extra decode cost. Render-loop-side control file, live without restart.
- **`Verify install`** green-menu action + installer-side checksum manifest
  (`/mnt/app/eso/lib/gal_dualscreen/verify_manifest.txt`, cksum-based).
- **Green-menu wiring**: two new toggle entries and a verify entry, all
  marked "(fork)" so they are easy to see apart from upstream's.
- **Docs**: `docs/FORK.md` (identity, licence, how to publish),
  `docs/Tiguan.md` (Tiguan AD1 AID10, what to measure on your car).
- Nothing in `src/` (the `gal` hook) was modified: all upstream profiles and
  fingerprints apply unchanged.

## Upstream changelog

Upstream's history is [in its own repository](https://github.com/MacsInSpace/mib-cluster-map/commits/main)
and is not reproduced here.

### Local build record (zoom-fork-local, 2026-11-05)

stream-player built locally from this tree (v1.1.1-beta18-16-g4b43ddf) with the
luka-dev/qnx65-armv7-toolchain 8.5 image (gcc 8.5, ffmpeg 6.1.5 mini:
--disable-everything --enable-decoder=h264 --enable-parser=h264, softfp
vfpv3-d16) and deployed to the M.I.B. Addon payload. Carries Zoom and the
keep-map arbiter. Built natively instead of in Docker on a TrueNAS LXC host
(the image's netavark/crun backends are restricted there); `/opt/qnx650`
symlinked to the unpacked image root. Pending the owner's car verification.

### Note on the 5x7 font (features-card-20261105 player)

`player/turnstrip.h` transcribes the classic public-domain 5x7 LCD font
(the table Adafruit's GLCD library popularised; values cross-checked for
the glyphs a road text needs). Credited here so the provenance is explicit.
