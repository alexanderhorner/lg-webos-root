# AGENTS.md

Instructions for coding agents reproducing the root documented in this
repository on a comparable TV. Read [docs/safety.md](docs/safety.md) first
and stay inside its rules: **never write to or remount-rw `/`, `/etc`,
`/usr`, or any system partition; never `chattr +i`; no firmware flashing.**

## Layout

- `docs/rooting.md` — the full write-up (read this before running anything)
- `docs/post-root.md`, `docs/safety.md` — what the root stack changes; rules
- `payload/` — the exact files to serve; see `payload/README.md`

## Prerequisites (verify before starting)

1. TV: LG OLED, webOS 11.x, firmware similar to `43.21.98`. Confirm over the
   Dev Mode shell (`ares-novacom … --run 'cat /etc/version 2>/dev/null; id'`)
   — expect `uid=5965(prisoner)`. That is normal: Dev Mode is never root.
2. LG Dev Mode app installed on the TV, webOS CLI device configured
   (`ares-setup-device`), and **an already-working `ares-novacom` session**.
   New key-server pairing prompts time out — do not rely on pairing.
3. Host machine on the same LAN. Get its IP: `ipconfig getifaddr en0`.
4. In `payload/`: fetch the two companions into `root/` (not bundled):
   - `autoroot.sh` from [SlopBro](https://github.com/throwaway96/slopbro)
     (AGPL v3+; do not commit it to this repo)
   - `hbchannel.ipk` from the
     [HBC v0.7.3 release](https://github.com/webosbrew/webos-homebrew-channel/releases/download/v0.7.3/org.webosbrew.hbchannel_0.7.3_all.ipk)
     (verify sha256 `d10bf3c753551d7c72fb7a92b20fcd2317e502a220ac668ba8e76f6ea78b363c`)
5. Serve the payload: `cd payload && python3 -m http.server 18080 --bind 0.0.0.0`
   (any static server works; the page's `/log` fetches 404 harmlessly).

## Reproduction, step by step

Each "run" = launch the page once. Between runs, edit the single
`const trigger=await call('…')` line in `payload/index.html` to the trigger
listed for that step (values and payloads are in `payload/README.md`).

**Stage 0 — probe (do this first, always).** Point the manifest/service at
`scripts/probe.sh` (harmless: writes `date; id; uname -a` to
`/tmp/root-probe-result`). Run the page with the install-style trigger, then
read the marker over the Dev Mode shell. Do not continue until it says
`uid=0(root)`. This proves the route with zero side effects.

**Stage 1 — install Homebrew Channel.** Restore the install payload
(`install.manifest.json`, `install.service`, `install-hbchannel.sh`) and
launch:

```sh
npx --yes --package @webos-tools/cli ares-launch --device <device> \
  com.webos.app.tinybrowser \
  -p '{"contentTarget":"http://<host-ip>:18080/index.html"}'
```

Verify from the Dev Mode shell (the page alone is not proof):

```sh
npx --yes --package @webos-tools/cli ares-novacom --device <device> --run \
  'ls -d /media/developer/apps/usr/palm/services/org.webosbrew.hbchannel.service && tail -20 /tmp/root-install.log'
```

The log must show `id` lines with `uid=0` and `autoroot rc=0`.

**Stage 2 — remove the Dev Mode app.** Trigger
`luna://com.webos.appInstallService/dev/remove` with
`{"id":"com.palmdts.devmode","subscribe":true}`. **This kills Dev Mode —
run it only after everything above verifies.** After this, `ares-*` access
is gone for good.

**Stage 3 — persistence.** Trigger
`luna://org.webosbrew.hbchannel.service/registerActivity` (`{}`). Without
this the root does not survive reboot on this model (no `start-devmode.sh`).

**Stage 4 — reboot and claim root.** Reboot the TV (power cycle or the
`machineReboot` luna call). webosbrew's `startup.sh` brings up a root telnet
on port 23 unless disabled. Connect, then immediately lock in SSH:

```sh
telnet <tv-ip>
# on the TV:
mkdir -p /home/root/.ssh && chmod 700 /home/root/.ssh
echo '<your-ed25519-pubkey>' > /home/root/.ssh/authorized_keys
chmod 600 /home/root/.ssh/authorized_keys
touch /var/luna/preferences/webosbrew_sshd_enabled
touch /var/luna/preferences/webosbrew_telnet_disabled
killall telnetd 2>/dev/null || true
```

Verify `ssh root@<tv-ip> id` → `uid=0(root)`, then reboot once more to prove
persistence survives a cold boot.

**Stage 5 — cleanup.** Remove the payload from the TV; keep the HBC
directories and `/var/lib/webosbrew/startup.sh`:

```sh
ssh root@<tv-ip> 'rm -f /media/internal/downloads/{install.manifest.json,install.service,install-hbchannel.sh,autoroot.sh,hbchannel.ipk}'
```

## Gotchas that cost time in the original run

- Downloaded files carry **no executable permission** — the service `Exec`
  must go through `/bin/sh`. Don't try to `chmod +x` downloads.
- The `Exec` wrapper must either run the installer **synchronously**
  (as `install-hbchannel.sh` does) or fully detach with
  `setsid … </dev/null >log 2>&1 &`. A half-detached child dies with the
  service process and the install silently never happens.
- **Any** method call on the registered service name launches the `Exec`.
  The trigger call's own response is often an error — that is fine; judge
  success by the log file and resulting files, never by luna output
  (`luna-send` regularly prints nothing at all).
- Manifest services are **transient**: if the hub restarted, re-download the
  manifest files under a new manifest id (bump the `id`/`version`) and call
  `addManifestsDir` again.
- The page must reach `PalmServiceBridge`/`webOSServiceBridge`. It does
  inside `tinybrowser`; it does **not** inside a normal sideloaded web app
  without the right ACG/permissions.
- If the trigger must come from the TV shell instead of the page:
  `/usr/bin/luna-send-pub -n 1 "luna://com.webos.service.bus/addManifestsDir"
  '{"prefix":"/media/internal/downloads","dirpath":"."}'` works from the Dev
  Mode shell.
- Blocking updates (`/var/luna/preferences/webosbrew_block_updates`) is a
  deliberate, reversible choice with a security trade-off — see
  [docs/safety.md](docs/safety.md) before setting it.

## If it fails

A failed run leaves a stock, working TV (worst case: reboot and re-run — the
root execution is repeatable). A crashed boot triggers webosbrew's failsafe
recovery telnet with customizations disabled. Nothing in this flow writes to
system partitions.
