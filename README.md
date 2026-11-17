# LG webOS 11 root

How a current-generation LG OLED TV on webOS 11 was rooted and what runs on
top of the root — written so the setup can be understood, reproduced, and
reverted.

Tested on an **LG OLED77C68LA** (board `O26_DVB_EU`), **webOS 11.2.0**,
firmware `43.21.98`, kernel `6.12.44-352` (aarch64). Verified working
2026-11-15.

## Why this exists

The jsserver root route (patched October 2026) no longer works on this
firmware. What still worked was the **Luna bus manifest loader**: a stock app
that exposes the Luna bus to a web page, combined with the download manager,
is enough to get a script executed as root. From there, the standard
[webosbrew](https://github.com/webosbrew) stack takes over.

## Contents

| Document | What it covers |
|---|---|
| [Rooting](docs/rooting.md) | The exploit chain step by step, its constraints, and cleanup |
| [Post-root setup](docs/post-root.md) | webosbrew + Glasshouse: every change vs. stock and its revert path |
| [Safety](docs/safety.md) | Brick risks, hard rules, failure modes, how to unroot |

## The short version

1. Launch the stock `com.webos.app.tinybrowser` at a LAN-hosted page via its
   `contentTarget` parameter.
2. From that page, `luna://com.webos.service.downloadmanager/download` places
   a manifest, a service file, and a script under `/media/internal/downloads`.
3. `luna://com.webos.service.bus/addManifestsDir` registers that directory as
   a Luna bus manifests dir.
4. Triggering the declared service runs its `Exec` as `uid=0`.
5. That root execution installs [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel)
   and registers its persistent Activity Manager autostart.
6. After reboot, `/var/lib/webosbrew/startup.sh` re-establishes root access
   (SSH) at every boot.

## Warning

**webOS TVs have no recovery mode.** A real brick means opening the panel and
reflashing the eMMC ([rootmy.tv/warning](https://rootmy.tv/warning)). This
setup was audited to stay off the brick paths, but read
[safety.md](docs/safety.md) before doing anything described here.
