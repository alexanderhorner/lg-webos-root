# Safety

## No recovery mode

webOS TVs have no recovery mode. A real brick means opening the panel and
reflashing the eMMC — see <https://rootmy.tv/warning>. That page names the two
known ways to permanently brick a TV:

1. **Writing to system partitions** (kernel, rootfs, tvservice, read-only
   areas): the bootloader verifies signatures and will refuse to boot. This
   includes `dd` to `/dev/mmcblk*` and USB firmware up-/downgrades.
2. **`chattr +i` immutable files**: they survive factory reset (user
   partitions are `rm -rf`'ed, not reformatted) and can break boot scripts
   for good.

Both were audited against this setup (2026-11-15):

- The full mount table contains **no writable system mount**: `/` is
  read-only squashfs, `/etc` and `/usr` are read-only overlays, so stray
  writes fail outright. Everything lives on `/var`, `/home`,
  `/media/developer`, or in runtime bind mounts that write nothing to disk.
- `lsattr -R` over the modified trees (`/home/root`, `/var/lib/webosbrew`,
  `/var/lib/tvweb`, `/media/developer/apps`) found **zero** immutable files.

## Rules

- Never write to or remount-rw `/`, `/etc`, `/usr`, or any on-flash system
  partition.
- No `dd` to `/dev/mmcblk*`, no firmware flashing, no USB up- or downgrades.
- Never make anything immutable (`chattr +i`).
- Only install homebrew from the webosbrew/Glasshouse upstream repositories.
- Keep a tested root SSH route before disabling any service; prefer
  reversible disables (runtime masks, bind mounts) over deleting system
  files.
- Do not reinstall LG Developer Mode while rooted.

## Realistic failure modes

- **Launcher or hook failure** → falls back to stock LG Home (the
  self-reverting paths were verified in the boot log).
- **Crashed boot** → webosbrew's failsafe kicks in: recovery telnet,
  customizations disabled.
- **Lost root** (HBC deleted, factory reset) → a fully working stock TV; the
  system partitions stay byte-identical to factory throughout.

## Unrooting / reverting

Each layer comes off independently; reboot and confirm stock behavior after
each step:

1. **Custom Home:** Glasshouse dashboard → Home → LG Home
   (or `POST /api/home/disable`). The Home bind mount disappears on reboot.
2. **Glasshouse:** remove its `init.d` hooks (`20-tvweb-services`, `50-tvweb`),
   delete `/var/lib/tvweb`, uninstall the dashboard app. The runtime masks,
   hosts bind mounts, and the iptables rule disappear with the next reboot.
3. **webosbrew root:** delete `/var/lib/webosbrew` (startup.sh, init.d
   hooks), remove the `/var/luna/preferences/webosbrew_*` flags
   (`sshd_enabled`, `telnet_disabled`, `block_updates`), and remove the HBC
   app and service directories under `/media/developer/apps` (HBC's own
   uninstall handles its Activity Manager registration).
4. Reboot — the TV is stock; system partitions were never touched.

A factory reset is the fallback if SSH is ever lost: it also produces a stock
TV (user partitions are wiped) — with the one caveat that immutable files
would survive it, which is why they are banned above.

## The OTA trade-off

Blocking LG updates (the HBC flag plus hosts entries for
`snu/su/su-ssl/nsu.lge.com`) is the largest deliberate deviation from stock.
It is standard webosbrew practice to protect root, but it also withholds LG
security fixes. Keep it as a conscious choice: keep the block and miss
fixes, or lift the block and accept that a firmware update may remove root
until a new route is found.
