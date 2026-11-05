# Install (copy & paste only)

**Prerequisite:** M.I.B. on the card and reachable in GEM. If M.I.B. is not yet installed on the unit, install it the usual way first (metainfo2 updater flow, from M.I.B.'s own instructions).

## 1. Prepare the SD card (at home, two copies, zero edits)

1. SD card FAT32, M.I.B. unpacked onto it exactly as its own release says.
2. Download this repository as ZIP, unpack, and copy its **`mod/` folder** into the card root — exactly the same place where M.I.B.'s own `mod/` folder lives, so they merge:
   card `mod/` now contains:
   - everything M.I.B. shipped there (unchanged),
   - `custom.sh`
   - `cluster_map_aa_greenmenu/`
3. That's the whole "installation" on the PC side.

## 2. In the car

1. Card into **SD slot 1**, unit on.
2. Hold **MENU → Testmode** → GEM.
3. **M.I.B. → Advanced Settings → “Run /mod/custom.sh from m.i.b. SD”**.
   Output confirms both steps:
   - `GEM screen installed on the unit: /net/mmx/mnt/app/eso/hmi/engdefs/cluster-map.esd`
   - the mod's installer output (profile check + hook install).
4. **Reboot** (hold the power button ~10 s).

## 3. Use

GEM → new top-level screen **ClusterMap**:

| Item | What it does |
|---|---|
| 1. Status and compatibility check | unit train, gal fingerprint vs `profiles.conf`, hook/jar state |
| 2. Install cluster map | the Android Auto → VC install (this is also what `custom.sh` already ran) |
| 3/4. Sharper map ON/OFF | full-frame vs standard cluster frame |
| 5/6. Keep map ON/OFF | cockpit source arbiter (map stays when other sources connect) |
| 7. Verify installed files | checksum check of the installed payload |
| 8. Uninstall | restores stock, removes the menu screen too |
| 9. Switch to turn-by-turn | trains without a map profile, using `VCAndroidAuto.jar` arrows |
| 10/11. Save logs / collect | diagnostic bundle to the card |

Then: phone on USB → Google Maps or Waze → cluster switched to map view.

## If the screen does not appear in GEM after the reboot

- Re-run “Run /mod/custom.sh”. (It is idempotent; it re-copies the screen file.)
- Check the card really is in **slot 1** (`sda0`).
- Confirm you hold MENU → Testmode **with GEM enabled** (M.I.B. patch run did that; otherwise a VCDS/OBDeleven developer-mode adaptation block **5F** is the fallback upstream asks for).
- One reboot *after* the copy is needed — the GEM reads the screen files at boot only.

## Uninstall

GEM → **ClusterMap → 8. Uninstall**: it restores the stock hook config and removes the menu screen. The card's `mod/` folder can then simply be deleted from the card at home.

## If the console says “NOT INSTALLED: the SD card is READ-ONLY to the unit”

1. SD adapter **LOCK slider** → unlock, re-insert, run the screen again.
2. Card must be **FAT32** (exFAT/NTFS mounts read-only on the unit).
3. Otherwise run **`chkdsk /f`** on the card from a PC — the dirty-volume bit makes the unit mount it read-only.

## Where the in-car switches live (and when they reset)

The switches (Sharper map, Keep map, Zoom) change the **installed settings on the unit**, not the card:

- they survive reboots and are read by every new phone session;
- the **Zoom 1.x** items additionally write the live file (`/tmp/stream-player.zoom`), so a running map picks the change up within seconds, no reboot;
- **a fresh Install from the card resets them**: a re-install from the card applies the card's own shipped settings file, which does not carry your in-car toggles. After any card re-install, simply re-click the switch you want (one click each) — or, if you keep a personal line set, save it on the card copy of `gal_dualscreen.conf` and it will win every time;
- `Uninstall` returns everything to the stock behaviour and forgets them.

## Trains & profiles

The install is gated by the upstream profile table (`profiles.conf` + `profile_check`): a unit that does not match refuses with a clear `NOT SUPPORTED` message (and collects a porting bundle instead). Do not try to bypass it.
