# Android Auto: capabilities and limits — a research note for this Addon

> Research basis (all read 2026-11-05, local):
> [f1xpl/aasdk](https://github.com/f1xpl/aasdk) — the community-standard
> open-source AA protocol library (its `.proto` set mirrors the closed
> protocol); our own hook source (`src/video_sink_hook.c` in
> mib-cluster-map-generic), which hand-writes these messages; the official
> [Android for Cars DHU guide](https://developer.android.com/training/cars/testing/dhu)
> (Google's own head-unit emulator — **its feature flags are de-facto
> official protocol documentation**); [f1xpl/openauto](https://github.com/f1xpl/openauto);
> and the sibling projects in `docs/related-projects.md`.
>
> Every claim here is either proto-verifiable (aasdk file references), seen in
> our own engine, or quoted from Google's own tooling docs. The last section
> lists concrete NEXT features, ranked, with the exact knob each one uses.

## 1. The protocol model in one page

AA is a channel-based protobuf protocol. The phone is the server; the head
unit is the client. Everything below is per-channel:

| Channel | What it carries | Our engine's use |
|---|---|---|
| **Control** (msg ids 1–11) | Version handshake, SSL handshake, ping, **service discovery**, shutdown | The hook **rewrites the discovery response** (`queueOutgoing`) to add the cluster video + input services and the vendor-extension data — this is what makes the phone believe there are two displays |
| **Input** | `InputEventIndication` with **key code events** (`KeyEvent`: keycode, down/up, metastate, longpress) and **relative events** (`RelativeInputEvent`: scan_code + delta, i.e. a rotary) | `build_input_report()` in the hook; the `/tmp/gal_inject` test harness; `GAL_CLUSTER_KEYCODES` configures the codes we advertise |
| **Video** | `VideoConfigData` (resolution, fps, DPR), focus request/indication, frame messages, acks | The cluster is added as a second **video sink**; focus switching implemented (`GAL_KEEP_MAP`-style arbitration in the fork player) |
| **Audio** (several channel ids) | Media audio, speech, system sounds, focus | Left to M.I.B.'s own audio path; not touched |
| **Sensor** | Speed, fuel, gear, parking brake, headlights/night, odometer, location, gyroscope — phone reads, HU sends | Partly used: the unit supplies speed/headlights already through gal's own path. A source of *future* data feeds, not UI |
| **Navigation** | status messages (turn/lane/ETA data) **and a `NavigationImageOptions` block: width, height, colour_depth_bits** | The exact knob behind our margins/full-frame sizing (§3) |
| **VendorExtension** | OEM/vendor-specific feature negotiation | Written into our discovery response, used as part of the two-display setup |

Proto evidence (files in the cloned aasdk): `InputChannelData.proto`
(`repeated uint32 supported_keycodes = 1`), `ButtonCodeEnum.proto`,
`RelativeInputEventData.proto`, `NavigationChannelData.proto`,
`NavigationImageOptionsData.proto`, `VideoConfigData.proto`.

## 2. Facts Google's own tooling tells us (de-facto official docs)

From the official **Desktop Head Unit (DHU)** guide — the emulator IS
spec-shaped, so every knob there is a protocol capability:

- Official AA resolutions: **480p (800×480), 720p, 1080p** — and for other
  shapes the HU sends **margins** (`marginwidth/height`, per-edge `margins =
  top,bottom,left,right`) plus **`contentinsets` / `stablecontentinsets`**
  and **`pixelaspectratio`**, and can request `cropmargins`. Our
  `GAL_SECONDARY_MARGINS`, `GAL_SECONDARY_INSETS` and
  `GAL_SECONDARY_PIXEL_ASPECT_RATIO_E4` are the same three concepts — the
  Sharper-map switch is **an officially-defined behaviour** (non-square
  pixels), not a hack.
- A video-capable **cluster display is officially emulated** in DHU ≥2.1:
  `[display:cluster] displaytype=cluster, resolution=800x480, dpi=…` with the
  same video options as the main display. Our second-display discovery
  approach is exactly this shape of setup.
- There is ALSO an official, **non-interactive instrument-cluster surface**
  (`instrumentcluster` / `navcluster` / `phonecluster` in the DHU config):
  status-only *text/icon* tiles — next turn info, distance/time, ongoing
  call. The phone composes those from its own navigation/call state. This is
  a status surface, not video: it does **not** render Maps' card, and it is
  not interactive.
- Focus is threefold (`focus video|audio|nav`) — the phone/`NavigationView`
  switches back when the HU withdraws navigation focus. This is the machine
  behind the stock-map switchback our `GAL_KEEP_MAP` arbiter counteracts.
- Day/night is an official sensor (`night_mode`), already handled by the
  hook's theme-follows-headlights logic.
- The DHU supports `keycode` commands limited to the official set (`home`,
  `back`, `call`, `media_play_pause`, `media_next`, …) — consistent with the
  ButtonCode enum: **there is no zoom keycode in AA's official button set**.

## 3. The phone's rendering model for maps (and the card)

The phone composes the cluster nav frame itself. What we control:

1. **The shape** (via `NavigationImageOptions` width/height + margins +
   pixel aspect): Google Maps letterboxes the drawn area to the shape we
   declare, then our player scales it to the window. This is what our
   margins/full-frame switches ride on.
2. **The safe area** (insets/content-insets): the phone is *told* which parts
   are covered by the dials.
3. **What we cannot control:** composition of Google Maps' own overlay — the
   green turn card is part of the picture Maps renders, and AA has no
   documented "hide/move the card" setting (CarPlay's card is a separate
   layer from Apple, which is why our CarPlay side can position it and the
   AA side cannot).

## 4. Input: what is and is not possible (the wheel-zoom question)

- The phone reads input on a per-display basis; a working two-display
  session has one input service per display (`5:0` main, `5:1` cluster in
  wire terms). Our hook builds exactly this (and deliberately leaves the
  main one stock — mis-tagging it is what broke the phone entirely in the
  DHU capture the fork documents: 83 ping timeouts, 0 controls).
- `supported_keycodes` (we advertise) ✓ and `RelativeInputEvent` rotary ✓
  are protocol capabilities our hook already emits. The observation
  upstream made — "the phone binds only the keys it advertises 23 and
  65536" — is the *binding site*, and it is **configurable on our side**
  (`GAL_CLUSTER_KEYCODES`), but the AA **button enum itself contains no zoom
  code** (`SCROLL_WHEEL` = 65536 is the closest); sending non-enum keycodes
  (the 168/169 Android zoom keys) was tested upstream and ignored.
- Wheel zoom as a *phone-rendered* zoom therefore has no path on AA (vs
  CarPlay, where the iAP2 `changeMapZoomLevel` diagnostic command exists and
  is car-proven — `docs/related-projects.md`). On AA the room that remains:
  + **player-side crop zoom** — built (v0.4.0), live via
    `/tmp/stream-player.zoom`;
  + **DSI-tracer wheel reading** driving that same player zoom — proposed,
    not implemented (`CLUSTERMAP_WHEEL_ZOOM`, needs a car round).

## 5. What limits remain (honest list)

- No third display (screen count is discovery-driven; two proven).
- No interactive/touch surface for the cluster in AA (even DHU cluster is
  status/`displaytype=cluster` video only).
- No documented way to alter Maps' own card composition.
- Video resolutions are the three official ones; shapes beyond them are
  margins/aspect composites (windows wider than 5:3 need the non-square-pixel
  trick — our Sharper map).
- Wireless AA adds handshake layers (Wi-Fi Direct); our engine is
  USB/TCP-transport-agnostic but car-testing is USB.

## 6. Concrete next features for the Addon (ranked)

| # | Feature | Knob used | Risk / Car round needed? |
|---|---|---|---|
| 1 | **Nav card relocation experiment**: emit official `contentinsets`/`stablecontentinsets` for the cluster display in the discovery response (the hook already writes several video-config fields by hand in `gal_secondary_config`). `stablecontentinsets` is what tells the phone to keep UI out of covered rectangles — the card may move rather than overlay the route | same discovery write path | Reverse a video-config field offset in `libautoreceiver.so` of the target train (tooling exists: `tools/armre.py`). One car round |
| 2 | **Turn-info in the AID lower bar**: our hook already parses nav turn messages for the arrows jar (`GAL_DUALSCREEN_NAV_TRANSLATE`). Write road name + ETA into the cluster's info bar via the existing dmdt write path (the same thing luka-dev does on MHI2Q's phone tab) | nav messages already in hand; dmdt writer exists (`dmdtgo`) | Half a day + car round (text rendering on AID10's bar) |
| 3 | **Dial-layout-aware margins** (joeyQuery's viewAreas analogue): read `setZoomArea` from the DSI tracer; switch `GAL_SECONDARY_INSETS`/window lines + nav image options per layout | DSI tracer (proven on this HMI); same infra as `CLUSTERMAP_WHEEL_ZOOM` | Needs the tracer's HMI restart; bundle with wheel-zoom work |
| 4 | **`GAL_CLUSTER_KEYCODES` made first-class**: document in the settings table + optional GEM item (currently the fork supports it but the docs don't) | `supported_keycodes` already in the hook | Doc + car round if a useful AA keycode set exists for Maps |
| 5 | Day/nigh & focus switches in GEM (`auto` theme, focus style) | sensor + focus fields | small |
| 6 | DHU as the **test sandbox**: reproduce our exact unit video config in an official DHU `.ini` (`[display:cluster] 800x480, margins, pixelaspectratio`) to see phone behaviour safely between car rounds | official DHU | none — runs on a laptop, no unit |

## 7. What this means for the roadmap

The next implementable wins are **1 and 2** — both reuse our own existing
write paths (discovery fields / nav messages), both are honest protocol
features rather than hacks (Google's own DHU exercises them), and both
attack known user pain points (the card overlay, the AID lower bar). The
wheel-zoom story on AA stays player-crop + (optionally) tracer-driven, and
that research line is already documented.

— Ledger pointers: this file is referenced from `LEDGER.md` §7; update both
when a candidate lands.
