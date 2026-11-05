# Adding the 4 screens to M.I.B.'s own `Launcher-sda0.esd`

> **Preferred: use the ready-made file `esd/cm_aa_screens.esd` from this repo.**
> It is already byte-exact in M.I.B.'s launcher format (ASCII, **CRLF** line
> endings, screen declared as a `=>M.I.B.<=` child, correct `script`
> indentation). You only *append* it to the end of your card's
> `Launcher-sda0.esd` — do not retype, reformat, or re-save it through an
> editor that could rewrite line endings (plain Windows Notepad would).
>
> Do **not** write the screens with wrong formats such as
> `screen <name> greenmenu` — the GEM has no such parent screen, so the
> entries would silently not appear. In M.I.B.'s launcher, a screen shows in
> the GEM root menu only with the parent `=>M.I.B.<=`
> (e.g. `screen cluster_map_aa =>M.I.B.<=`, same pattern as M.I.B.'s own
> `screen vim =>M.I.B.<=`).

## Option A — Linux / macOS / WSL (recommended)

```sh
cd /media/<YOUR-SD-CARD>
cat <path-to-this-repo>/esd/cm_aa_screens.esd >> Launcher-sda0.esd
```

## Option B — Windows (without touching an editor's line endings)

In a Command Prompt:

```bat
cd /d X:\              REM your M.I.B. SD card drive
type <repo-folder>\esd\cm_aa_screens.esd >> Launcher-sda0.esd
```

(The block file already begins on a fresh CRLF line, so a plain byte append
is safe.)

## Option C — manual paste (Notepad++, only if A/B are impossible)

1. Open `Launcher-sda0.esd` in **Notepad++**.
2. Menu **Edit → End-of-File … set EOL to 'Windows (CR LF)'** *for the launcher
   file only*, then jump to the very end of the file.
3. Open `esd/cm_aa_screens.esd` in a second tab; copy **everything** in it and
   paste it at the end of the launcher tab.
4. Always **save as plain ASCII/UTF-8 without BOM**. Never let Notepad++
   convert to UTF-8-BOM or LF-only — either would break the GEM.

## Check it worked

After editing or appending, search your card's `Launcher-sda0.esd` for
`cm_aa`:

* exactly one block → screens are live at the next boot.
* zero hits → paste didn't land.
* more than one → undo (delete the extra block) and retry; double screens
  would double-list in the GEM.

## What the added screens do

Each item runs a **wrapper script on the card** under
`/net/mmx/fs/sda0/esd/scripts/cm_aa_*.sh`, which calls the fork's own payload
in `mod/cluster_map_aa_greenmenu/` — status, install, uninstall and log
collection. They only show up at the next complete boot with the SD card
inserted (hold **MENU → Testmode** → GEM, then **Cluster map — Android Auto →
Virtual Cockpit**).
