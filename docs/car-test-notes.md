# Car test notes — the Tiguan AD1 unit this Addon was verified on

(MHI2_ER_VWG13, 9.2-inch AID10 virtual cockpit. This file is a record of the
one car where the full chain is verified to date; every other supported train
is untested and profile-driven.)

**What the Tiguan AD1 is**, hardware-wise for this project:

| Piece | Value |
|---|---|
| Head unit | `5NA035020D` glovebox unit, Discover Pro MIB2.5 High (Harman) |
| Firmware family | `MHI2_ER_VWG13_*` — P4521, K4525, P4512, P4174, P4521_1 |
| Cluster | 10.x-inch Active Info Display (`3G0920790E` family, VDO/Continental build) |
| Cluster link | MOST150 optical — the project's AA map rides the same path the car's own map does |

Your train is one of the **tested trains** — the installer picks the existing
`MHI2_ER_VWG13_P4521` profile because the `gal` binary build matches, and the
`train` row lists `map navignore arrows` for it. You do not need a port.

## Verified working end-to-end

The complete chain was exercised on this unit and works:

    SD1 card -> M.I.B. -> Advanced Settings -> "Run /mod/custom.sh"
    -> ClusterMap screen on the unit -> Install
    -> libgal_hook.so preload + stream-player
    -> Android Auto phone map on the cluster (Google Maps / Waze).

One integration obstacle was found and fixed during the verification:
on this unit, the GEM console runs on a core without a local card
reader (the card is a QNET mount of the mmx node's device:
"/net/mmx.mibhigh.net/dev/sda0t12 on /fs/sda0"), so the installer's
card remount must be issued on that node/device. The green-menu code
now runs a remount ladder (local path, QNET device, on -f <full node
name>, /bin/mount on mmx) with a real write-probe, and only then
installs.

## Measured on the unit (owner to fill from the Status screen)

Fill this card from the ClusterMap -> Status output on the actual car
(paste the whole screen and keep the raw lines too). These become the
MHI2_ER_VWG13 reference values:

| Value | Value on this unit |
|---|---|
| Cluster map window (`GAL_PLAYER_WINDOW`, from the install live read) | WxH ______ |
| `GAL_SECONDARY_DPI` the installer picked | ______ |
| `GAL_SECONDARY_INSETS` applied | ______ |
| `GAL_VC_CONTEXT` | ______ |
| Profile row used | `MHI2_ER_VWG13_P4521` (gal fingerprint match) |
| Sharper map applicable for this window | (window wider than 5:3? yes/no; note Zoom 1.15/1.35 results) |
| Turns/zoom behaviour noted | — |

## What to measure on your car (Your first install)

Only two things are Tiguan-specific and unset upstream today, because no
Tiguan owner has posted their values yet:

1. **Cluster map window size** — the installer records it in
   `ClusterMap/update_result.txt` ("live window size"). Note it from the
   first run: this fork's docs want the Tiguan's number recorded (mine
   measured: __fill in after your install__).
2. **DPI and insets** that make Google Maps look right between the dials.
   The current VW default is `GAL_SECONDARY_DPI=138`,
   `GAL_SECONDARY_INSETS=52,82,127,127` with an `800x480` window — a good
   first value on the Tiguan too, but the cockpit's AID10 might want
   `1010x376`-style insets rather than Golf values. If the map sits behind
   the dials or the label is too small, tune:

```
ClusterMap/gal_dualscreen.conf (on the SD card):
GAL_SECONDARY_DPI=138          # bigger = smaller text, more map
GAL_SECONDARY_INSETS=52,82,127,127  # top,bottom,left,right, 0..127
```

then run the update again. Values that work get added to
[Install.md § Owners have settled on](Install.md#settings-owners-have-settled-on) and
arrive with the next release for every Tiguan owner.

## Fork features worth knowing on a Tiguan

- **`Keep map` green-menu toggle** — re-asserts the phone's map on the
  cluster when the car's own map switches back in. Useful for the
  CarPlay switch-back upstream still tracks (#19/#43) and for any stock-HMI
  race during route recalculations.
- **Zoom** — now shipped live in the ClusterMap screen (Zoom 1.0 / 1.15 / 1.35):
  `GAL_PLAYER_ZOOM_E4` in the settings plus `/tmp/stream-player.zoom` (one
  float, e.g. `1.35`) applied without a session restart. Requires the
  fork-built `stream-player` (zoomed in this card's payload); against the
  upstream release player the switch refuses with a clear message. Handy when
  the map's labels feel small on the 10.25″ AID10's 800×480 window.
- **`Verify installed files`** — if the map won't start, this tells you
  first whether the installed files still match the installer's manifest
  (vs your settings being wrong, vs the phone refusing).

## Other firmware notes for Tiguan AD1 owners

- If your Tiguan is from a region with `MHI2_US_VWG13_P3662`, upstream
  already road-tested it — nothing to change.
- Any *MIB2 Standard* (Composition/Discover Media `MST2_*`) is **not** what
  this project targets — there the community route is
  `mib-std2-kombibridge`-style work, not this code.

## Safety reminders (same as upstream)

- Install only with the battery healthy and the car stationary; never while
  driving.
- Keep the SD card around: it's the recovery path.
- Save logs (`ClusterMap` green-menu screen) before rebooting when
  reporting problems.
