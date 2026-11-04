# M.I.B. integration block — mib-cluster-map-tiguan AA→VC screens
#
# HOW TO USE: copy the block below to the END of your SD card's
# `Launcher-sda0.esd` file (or insert it, as a screen, into an existing
# screen). The screens appear under a new top-level GEM section
# "Cluster Map (Tiguan fork)" and drive the fork's own scripts
# (enable_hook.sh / disable_hook.sh / hook_status.sh / collect_logs.sh)
# inside `mod/cluster_map_aa_greenmenu/` on the same SD card.
#
# Make sure the fork payload is at
#     /net/mmx/fs/sda0/mod/cluster_map_aa_greenmenu/
# (scripts/, profiles.conf, libgal_hook.so, stream-player, ...)
# before you try to install from the M.I.B. GEM. See `README.md` in
# this folder for the exact copy list.
#
# If you want the "AA map zoom" (dmdtgo) runtime helper, place the fork's
# `dmdtgo` and `gal_dualscreen.default.conf` files in the mod folder too —
# the fork's own `enable_hook.sh` copies them at install time.
#
# NOTE:
#    These screens do NOT replace M.I.B.'s bundled CarPlay Maps VC payload
#    (`mod/carplay_maps_vc/omonob/`). Install only ONE of the two — they
#    write to the same unit paths (`carplaymaps/`, `CarPlayClusterControls*.jar`,
#    `altscreen-most-bridge`), and installing both breaks the cluster.
#    The screens below are only for the **Android Auto → VC** hook
#    (`libgal_hook.so`), which M.I.B. does not ship.
#
# ---------------------------------------------------------------
#
#     Main → Cluster Map (Tiguan fork) — Android Auto on VC
#
# ---------------------------------------------------------------

screen cluster_map_aa greenmenu

keyValue
    value   String sys 0x00000000 0
    label   "Cluster Map — Tiguan fork (mib-cluster-map)"
    label   "Android Auto → Virtual Cockpit  (Gal hook)"
    poll    0

keyValue
    value   String sys 0x00000000 0
    label   "Requires: M.I.B. option 7 (AA coding) already applied."
    label   "Requires: fork payload in mod/cluster_map_aa_greenmenu."
    poll    0

script
    value   sys 1 0x0100 "/net/mmx/fs/sda0/esd/scripts/cm_aa_status.sh"
    label   "1. Status (is the hook loaded? what does the phone see?)"

script
    value   sys 1 0x0100 "/net/mmx/fs/sda0/esd/scripts/cm_aa_install.sh"
    label   "2. Install AA→VC hook (writes the fork's hook + player)"

script
    value   sys 1 0x0100 "/net/mmx/fs/sda0/esd/scripts/cm_aa_uninstall.sh"
    label   "3. Uninstall AA→VC hook (restores stock gal/no hook)"

script
    value   sys 1 0x0100 "/net/mmx/fs/sda0/esd/scripts/cm_aa_collect.sh"
    label   "4. Save fork logs to the SD card"

keyValue
    value   String sys 0x00000000 0
    label   "Uninstall restores stock gal + smartphone_integrator.json."
    poll    0

keyValue
    value   String sys 0x00000000 0
    label   "This does NOT write persistence bits: M.I.B. option 7 does that."
    poll    0
