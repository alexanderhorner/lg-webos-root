# Post-root setup

What the rooted TV runs on top of stock webOS — the webosbrew root stack and
the Glasshouse dashboard — and how each piece is reversible. This mirrors a
read-only audit of a live setup (verified 2026-11-15).

**Overall property:** nothing persistent is written to the system image. `/`
is read-only squashfs; `/etc` and `/usr` are read-only overlays. Every
system-level effect is a runtime bind mount, a runtime mask, or a running
process, re-established at boot from `/var/lib/webosbrew` and `/var/lib/tvweb`.
Uninstalling means removing the hooks and flags below and rebooting.

## Root stack (webosbrew)

| Change | Where | Notes |
|---|---|---|
| Homebrew Channel 0.7.3 + elevated service | `/media/developer/apps/usr/palm/{applications,services}/org.webosbrew.hbchannel*` | LS2 elevation via `elevate-service`; `jumpstart.sh` re-roots after boot |
| webosbrew boot script | `/var/lib/webosbrew/startup.sh` | Stock webosbrew script, run elevated at every boot: failsafe-telnet mechanism, motd bind mount, telemetry neutering (read-only empty dirs over `/tmp/rdxd`, `/tmp/uploadd`, `/var/spool/rdxd`, `/var/spool/uploadd/*`), runs `init.d` hooks |
| Boot hooks | `/var/lib/webosbrew/init.d/` | Where Glasshouse's two hooks live (below) |
| SSH enabled flag | `/var/luna/preferences/webosbrew_sshd_enabled` (= 1) | Starts dropbear at boot |
| Telnet disabled flag | `/var/luna/preferences/webosbrew_telnet_disabled` (exists) | No telnetd process; failsafe flag absent |
| Update block flag | `/var/luna/preferences/webosbrew_block_updates` (= 1) | Adds LG update servers to the bind-mounted `/etc/hosts` — see [safety.md](safety.md) |
| Root SSH | webosbrew dropbear, port 22 | Key-only; host keys in `/var/lib/webosbrew/sshd`. `/etc/shadow` stays the untouched stock file with `root:*` — the account is locked, so password auth cannot succeed |

The stock systemd units mentioning dropbear stay unmodified; SSH comes only
from the webosbrew-started binary.

## Glasshouse

[Glasshouse](https://github.com/rorygallagher2024/glasshouse)
(`com.tvweb.dashboard`, 0.151.0) is a dashboard server for rooted TVs. It
installs through Homebrew Channel and keeps everything it changes reversible.

| Change | Where | Notes |
|---|---|---|
| Node server + watchdog | `/var/lib/tvweb/tvweb.js`, `tvwebctl` | Port 8080 on all interfaces, token-gated; config incl. the token in `config.json` (mode 600) |
| Disabled stock services | `init.d/20-tvweb-services` + `disabled_services.json` | Stops and runtime-masks (re-created each boot via `/run/systemd/transient`) six stock services: `uploadd`, `rdxd`, `camera`, `contentminer`, `nudge`, `remotelogger` |
| Main boot hook | `init.d/50-tvweb` | Adblock hosts, SAM rescan nudges (transient luna config, reverted immediately), preload-off resend, Home takeover, server start |
| Home takeover | `/var/lib/tvweb/home-takeover` bind-mounted over `/usr/palm/applications/com.webos.app.home` | How a custom launcher replaces LG Home; LG's Home auto-launch is switched off, stock value tracked as `lgAutoLaunch` in `home.json` |
| Adblock | `/var/lib/tvweb/adblock_hosts` bind-mounted over `/etc/hosts` | Includes the LG update servers; also bind-mounted into the YouTube, Netflix, Amazon and Thinq AI app jails (`/tmp/hosts` in each jail) |
| Preload manager | `/var/lib/tvweb/preload.json` | Preloading re-disabled at every boot for LG Channels, Netflix, Amazon, membership |
| DevTools firewall | iptables `INPUT … --dport 9998 ! -i lo -j DROP` | WAM's Chromium DevTools (bound on `0.0.0.0:9998`) stays reachable only from the TV itself |

Inactive Glasshouse machinery (present, not in use): tile hiding, per-app DNS
override, upstart-path service stops.

### Custom launcher without sideload

Glasshouse serves a custom Home launcher from an uploaded IPK under
`/var/lib/tvweb/home-launcher/`:

- upload: `POST /api/home/launcher/upload?name=<file.ipk>&k=<token>`
  (Content-Type `application/octet-stream`),
- choose/enable: dashboard Home tab, or `POST /api/home/enable` / `disable`.

The launcher is unknown to SAM (not an installed app) — removing it is a
directory delete. The upload preserves the chosen launcher and its
Glasshouse-backed preferences.

### Power-on shows Live TV before the launcher

Expected with a custom Home: `bootd` opens the last input before the boot
hook takes over Home. Enabling **Quick Start+** (Settings → General → System)
makes power-on resume straight into the launcher — a stock setting, no
scripts, no hidden-input hacks.

## Debloat inventory

Services Glasshouse can disable, with observed effect:

| Service | Category | Effect if disabled | Risk |
|---|---|---|---|
| `uploadd` | Telemetry | Stops upload of crash logs, diagnostics, usage telemetry | Safe to disable first |
| `rdxd` | Flash writes / diagnostics | Stops continuous diagnostic and crash logging to flash | Safe after `uploadd` |
| `contentminer` | ACR / viewing habits | Stops automatic content recognition / ad indexing | Safe |
| `remotelogger` | Remote logging | Stops system log shipment to LG | Safe |
| `nudge` | Promotions | Stops marketing popups/tips | Safe |
| `camera` | USB camera daemon | Stops USB webcam detection | Safe if no USB camera |
| `accountmanager` | Cloud account | Breaks LG account sign-in, ThinQ, LG Content Store | Only if those are unused |

Broader-impact units observed running: `update`, `update-remote-config`,
`pushclient`, `voiceinput`, `voiceconductor`, `ssdp-discovery-lgtv`,
`google-home-controller`, `homelaunchpoints`. Test these one at a time; do not
bulk-disable without checking input, remote control, casting, update, and
account behavior.

All disables are runtime systemd masks re-created at boot — nothing permanent.

## Network surface

Only non-stock LAN listeners: **22** (dropbear) and **8080** (Glasshouse).
Everything else in `netstat` is stock webOS; port 9998 is firewalled to
loopback; no other iptables rules.

## Secrets hygiene

- Glasshouse token lives in `/var/lib/tvweb/config.json` (mode 600); treat it
  as a root-equivalent credential — it can upload and launch code.
- One authorized SSH key; the root account stays locked in the stock
  `/etc/shadow`.
- Keep tokens, keys, and any recovery key material out of public repositories.
