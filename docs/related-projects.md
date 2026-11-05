# Related projects, and what we can borrow

Researched 2026-11-05 (GitHub sweep + local code analysis of the repositories
listed under "Cloned to /tmp/opencode/mib2/similar"). Every claim below is
backed by that repo's own docs/traces; the "adopt?" column says what this
project could actually take. Licenses checked; GPL projects credited where
their patterns are re-derived.

## The headline finding: wheel zoom IS car-proven on this family

Upstream concluded "no input was found that makes the phone zoom the map it
draws for the cluster" (`docs/Development.md → Zoom`). Two independent
projects on the same Harman MHI2 platform have now disproven the *practical*
part — zoom works, on the car, through the host-side input path:

| Source | Platform | What they proved |
|---|---|---|
| [joeyQuery/MHI2-altScreen](https://github.com/joeyQuery/MHI2-altScreen) — `traces/TRACE-015-cluster-controls.md`, `docs/cluster-controls.md` (GPL-3.0) | Audi MHI2 `MU0678`, train `P3241` (same Harman HMI as ours) | Wheel notches read from the **HMI DSI tracer** (`DSIKeyPanelListener#updateEncoder2`, keyboard 4, encoder 40, ±1), mapped to zoom; **car-working** |
| [aberbic/Audi-MHI2-Virtual-Cockpit-Altscreen-CarPlay-AndroidAuto](https://github.com/aberbic/…) (GPL-3.0) | Tegra audi `MU1438` | Own AA stack with an **AA wire zoom report** and an input bridge on loopback UDP 19822 (`aa_input.h`, `aa_zoom_report()`); touchpad input marked unfinished, zoom reported in their tests |
| [chefranov/mhi2-au37x-carplay](https://github.com/chefranov/mhi2-au37x-carplay) | Audi AU37x | Roller zoom working ("cable only"), wheel-roller map/stock swap, Siri shortcut; own units own input wiring |

**Key mechanism (joeyQuery, verbatim-authority):** the Harman HMI has a DSI
tracer that can stream its own Java-engine calls over telnet/bluepirat
appenders. Scoped in
`/mnt/app/eso/hmi/lsd/traceConfig.properties` (original kept as `.orig`, a
restart needed, boot slightly slowed), the hook or a client connects (~20 s
after boot) and reads live lines like:

    1#org.dsi.ifc.keypanel.DSIKeyPanelListener#updateEncoder2#<ts>|int:4|int:40|int:±1|int:0|int:1

encoder 40 ±1 = wheel notch up/down. Layout changes come as
`DSIMapViewerZoomEngine#setZoomArea` Rect lines (two layouts proven, third
untested). chefranov has the same idea on their branch.

**Verified on our own firmware trees (VW image, `/tmp/opencode/mib2/unpack`):**
`eso/hmi/lsd/traceConfig.properties`,
`DSITracer-VW-H29.319.75.jar`, `DSITracer.jar`+`clientData.bin`, and the
factory proxies `libdsimapproxy.so` / `libdsikeypanelproxy.so` all exist —
the same HMI tracer infra is present on the VW MHI2 this Addon targets.

### Adopt? — `CLUSTERMAP_WHEEL_ZOOM` (proposed, opt-in)

Design for this Addon (no upstream architectural change):

1. **Opt-in only** (`CLUSTERMAP_WHEEL_ZOOM=1` in the card's
   `gal_dualscreen.conf`). The tracer needs an HMI restart on enable, and
   slows boot slightly — it must never be a silent side effect of Install.
2. A new green-menu item + `wheel_zoom.sh`:
   - enables the tracer scoping (writes the scoped properties + marker,
     restarts the HMI the way M.I.B.'s own tools restart it), revert switch
     restores `.orig` and removes the marker;
   - starts a small client (`wheel_listen`, one `socket()` TCP push,
     QNX-side, built with the local toolchain like `profile_check`) reading
     the tracer stream and writing ±1 steps into the player's existing
     `/tmp/stream-player.zoom`.
3. Wheel press intentionally left unmapped (joeyQuery reached the same
   conclusion: it is the cluster's own gauge-size control; mapping it moves
   cards and the centre).

Estimated effort: the client + wiring ≈ half a day; the car-test round is the
real cost (tracer restart, live confirmation). It would land the wheel-zoom
topic end-to-end: wheel notches flow straight into the zoom path this Addon
already shipped in v0.4.0 (`GAL_PLAYER_ZOOM_E4` + the live
`/tmp/stream-player.zoom`).

## Other adoptable patterns

| Repo (license) | Feature / pattern | Adopt? |
|---|---|---|
| MHI2Q-CarPlay-AltScreen (514★; ~custom license, V3.7+ open) | Root-of-card `SHA256SUMS-SD.txt` so an owner can verify their copy/paste **on a PC** before booting the unit; card-position GEM switches (LEFT/TOP/RIGHT); GEM trimmed to 3 entries; boot-log auto-save | Partially: a GEM screen with a two-tier layout is a UX idea only; integrity is already stronger here (Verify on-unit) — was waived |
| [edzenis/mib2high-carplay-altscreen-rgi](https://github.com/edzenis/mib2high-carplay-altscreen-rgi) (per-component) | **RGI = factory HUD route guidance** on Harman MIB2 High with the factory hardware; separate (safe) render bridge | Interesting follow-on project for HUD owners; too big to fold into this Addon (own bus, own files) — note for a separate project |
| [luka-dev/mib2q-carplay-rgi](https://github.com/luka-dev/mib2q-carplay-rgi) (447★) | RGI guidance on MHI2Q (Qualcomm), cover art, calls, spatial audio | MHI2Q is a different hardware family; no direct transplant. Its "CarFire/Netflix" jargy is great docs polish (noted style) |
| [harman-f/mhi2_altscreen_carplay](https://github.com/harman-f/mhi2_altscreen_carplay) (GPL) | We already ship their lib; check periodically for updates to the cluster-stream hook | Track upstream: re-vendor if they add input handling or CarPlay layout changes |
| 1mikew/mst2-altscreen-carplay (25★, WIP) | MIB2 Standard (different SoC) | Watch only |
| [chefranov/mhi2-au37x-carplay](https://github.com/chefranov/mhi2-au37x-carplay) | Album art on VC, touchpad→D-pad, Siri shortcut (Audi-specific bus) | Not portable to VW Tegra (input/jar layer differs) — noted for a sibling Audi project |

## Status: none of the above adopted yet

The wheel-zoom design above is written up but **not implemented** — it needs
a car-test round (its first enablement touches the HMI tracer). When the
card's current fork-player build has car-verified, start there.
