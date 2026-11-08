# Install (copy & paste only)

**Prerequisite:** M.I.B. on the card and reachable in GEM. If M.I.B. is not yet installed on the unit, install it the usual way first (metainfo2 updater flow, from M.I.B.'s own instructions).

## 1. Prepare the SD card (at home, two copies, zero edits)

1. SD card FAT32, M.I.B. unpacked onto it exactly as its own release says.
2. Download this repository as ZIP, unpack, and copy its **`mod/` folder** into the card root — exactly the same place where M.I.B.'s own `mod/` folder lives, so they merge:
   card `mod/` now contains:
   - everything M.I.B. shipped there (unchanged),
   - `custom.sh`
   - `cluster_aa/`
3. That's the whole "installation" on the PC side.

## 2. In the car

1. Card into **SD slot 1**, unit on.
2. Hold **MENU → Testmode** → GEM.
3. **M.I.B. → Advanced Settings → “Run /mod/custom.sh from m.i.b. SD”**.
   That one run does everything:
   - validates the screen file and installs the GEM screen
     (`GEM screen installed on the unit: …/engdefs/cluster-map.esd`),
   - stages **and arms** the hook (the shipped payload carries `HOOK_ARMED`)
     and backs up the unit's stock player,
   - writes the ONE diagnostic file to keep and prints its name.
4. **Reboot** (hold the power button ~10 s). The map is on the cluster.

**Stage-only instead of live:** delete `mod/cluster_aa/HOOK_ARMED` from the
card before step 3 — nothing live is touched. Arm later from the GEM
(**ClusterMap → 2b. Make the map LIVE**), no card edit and no PC needed.

## 3. Use

GEM → new top-level screen **ClusterMap**:

| Item | What it does |
|---|---|
| 1. Status and compatibility check | unit train, gal fingerprint vs `profiles.conf`, hook/jar state |
| 2. Install cluster map | the Android Auto → VC install (this is also what `custom.sh` already ran) |
| 2b. Make the map LIVE | arms the hook from the GEM (reboot after) — for a stage-only install |
| 3/4. Sharper map ON/OFF | full-frame vs standard cluster frame |
| 5/6. Keep map ON/OFF | cockpit source arbiter (map stays when other sources connect) |
| 7. Verify installed files | checksum check of the installed payload |
| 8. Uninstall | restores stock, removes the menu screen too |
| 9. Switch to turn-by-turn | trains without a map profile, using `VCAndroidAuto.jar` arrows |
| 10/11. Save logs / collect | rebuilds the diagnostic bundle (`diag.txt`) |

Then: phone on USB → Google Maps or Waze → cluster switched to map view.

## "Script not found ..." on every ClusterMap entry

That one line means: the GEM screen **installed on the unit** names a
payload path that is no longer on the card (payload renamed or moved, or
an old folder was deleted during an update). The menu cannot run anything
until the screen is re-anchored once:

1. put the CURRENT release's `mod/` onto the card (merge, keep the card in
   SD slot 1),
2. **M.I.B. → Advanced settings → "Run /mod/custom.sh from m.i.b. SD"** —
   an armed run regenerates the screen with the card's live path (and the
   `diag.txt` card copy is retried and narrated),
3. reboot. The buttons are alive again; the console's first line names the
   payload version that is REALLY on the card.

## If the screen does not appear in GEM after the reboot

- Re-run “Run /mod/custom.sh”. (It is idempotent; it re-copies the screen file.)
- Check the card really is in **slot 1** (`sda0`).
- Confirm you hold MENU → Testmode **with GEM enabled** (M.I.B. patch run did that; otherwise a VCDS/OBDeleven developer-mode adaptation block **5F** is the fallback upstream asks for).
- One reboot *after* the copy is needed — the GEM reads the screen files at boot only.

## Uninstall

GEM → **ClusterMap → 8. Uninstall**: it restores the stock hook config and removes the menu screen. The card's `mod/` folder can then simply be deleted from the card at home.

## If the cluster map stops showing after a phone reconnect

The hook protects the unit: when it cannot verify that the unit's AA
program matches a profile in the table, it leaves stock gal untouched (no
map). The GEM console's **Last hook events** tells you which of these:

| Log line | Meaning | Fix |
|---|---|---|
| `firmware.profiles result=missing` / `firmware.verify … no_profile` | the unit has **no profile table** — the install that copies it never ran (or ran from an old payload) | re-copy the zip's **whole `mod/` folder** onto the card, then Run /mod/custom.sh **again**, then reconnect the phone. `custom.sh` now prints a one-line **unit files:** verdict (the full `ok:` list is in `diag.txt`) — `not present on the unit yet` is the instruction to re-run |
| `firmware.verify … profile_check` | the table is there but your train's AA files differ | send the Save-logs bundle; do not edit the table |

So: map not showing after an update is almost always the **install not
re-run** rather than the unit breaking. The self-check makes that state
visible at install time.

## The card is never written (since v0.4.20)

The add-on treats the SD card as **read-only media**. Backups, logs and
staging all live on the unit's RAM (`/tmp/clustermap_unit`, `/tmp`);
Uninstall's recovery copy is kept beside the unit's supervisor config, so it
survives reboots. The only card write left is ONE best-effort copy of the
diagnostic bundle (`mod/cluster_aa/diag.txt`), and a card that refuses it
changes nothing (the RAM copy stays authoritative).

**Why the card copy may be absent (the usual cause):** the unit mounts a FAT
card **read-only** when the volume's dirty bit is set — which happens after a
card is pulled from the PC without a proper eject. The run still installs and
the map still works, but `diag.txt` never lands on the card and the GEM
screen says so: `card copy: NOT WRITTEN`. On the next run the screen also
prints the picture-tuning facts, so send the photo while you fix the card.

Why this matters: our own earlier writes to the FAT card set its dirty bit,
and QNX then mounted the card read-only on the **next boot** — the source of
every “SD card is READ-ONLY” report since the first release. That diagnosis
was wrong.

A card written by an **older release** may still carry the dirty flag; clear
it once on a PC and it is done for good:

1. `chkdsk /f X:` on the card (Windows) — clears the dirty bit.
2. Card must be **FAT32** (exFAT/NTFS mounts read-only on the unit).
3. SD adapter **LOCK slider** → unlocked.

## Where the in-car switches live (and when they reset)

The switches (Sharper map, Keep map, Zoom) change the **installed settings on the unit**, not the card:

- they survive reboots and are read by every new phone session;
- the **Zoom 1.x** items additionally write the live file (`/tmp/stream-player.zoom`), so a running map picks the change up within seconds, no reboot;
- **a fresh Install from the card resets them**: a re-install from the card applies the card's own shipped settings file, which does not carry your in-car toggles. After any card re-install, simply re-click the switch you want (one click each) — or, if you keep a personal line set, save it on the card copy of `gal_dualscreen.conf` and it will win every time;
- `Uninstall` returns everything to the stock behaviour and forgets them.

## Trains & profiles

The install is gated by the upstream profile table (`profiles.conf` + `profile_check`): a unit that does not match refuses with a clear `NOT SUPPORTED` message (and collects a porting bundle instead). Do not try to bypass it.
