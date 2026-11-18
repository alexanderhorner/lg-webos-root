# Rooting

## Context and prior art

LG Developer Mode alone does not give root: its SSH shell is the `prisoner`
account (`uid=5965`), limited to installing and debugging apps. The known
software routes at the time:

- [RootMyTV](https://rootmy.tv) and the older SlopBro routes — for earlier
  firmware generations.
- The jsserver route (patched October 2026) — no longer works on this
  firmware (`43.21.98`).
- The **Luna bus manifest loader** route, described in
  [SlopBro issue #73](https://github.com/throwaway96/slopbro/issues/73) and
  confirmed persistent on a C4 at `43.21.96` — this is what worked here.

The underlying API is not secret:
[`com.webos.service.bus/addManifestsDir`](https://www.webosose.org/docs/reference/ls2-api/com-webos-service-bus/)
is documented in webOS OSE. Registering a *manifests directory* lets bus
clients declare services whose `Exec` the hub runs — as root.

## Prerequisites

- A TV on webOS 11.2.0 / firmware 43.21.98 (exact combination verified; the
  primitives are long-standing webOS APIs).
- LG Developer Mode set up with the webOS CLI (`ares-setup-device` etc.) —
  used here to launch the stock browser at the payload page. Any other way
  to open `com.webos.app.tinybrowser` at a URL works too.
- A machine on the same LAN serving the [payload](../payload/README.md)
  over HTTP, with SlopBro's `autoroot.sh` and the Homebrew Channel IPK in
  `root/`.

## How it works

- `com.webos.app.tinybrowser` launched with
  `{"contentTarget":"http://<lan-host>:18080/index.html"}` loads an arbitrary
  page that still has a `PalmServiceBridge` / `webOSServiceBridge` — a
  privileged Luna bus client.
- From that page,
  `luna://com.webos.service.downloadmanager/download` places files in
  `/media/internal/downloads` (user partition, no exec permission).
- `luna://com.webos.service.bus/addManifestsDir` with
  `{"prefix":"/media/internal/downloads","dirpath":"."}` registers the
  directory as a manifests dir.
- The manifest (`install.manifest.json`) points at a D-BUS service file
  (`Type=dynamic`) whose `Exec` must go through `/bin/sh` — downloaded files
  carry no executable permission.
- **Any** call to the declared service name (e.g.
  `luna://com.example.install/test` — the method is irrelevant) makes the
  hub launch the `Exec` as `uid=0`.
- Manifest services are transient: after a firmware or service restart, a
  new manifest ID is needed.

## Stage 0 — probe first

Before installing anything, run the same chain with a harmless marker
service (`scripts/probe.sh`: writes `date; id; uname -a` to
`/tmp/root-probe-result`) and read the result over the Dev Mode shell. This
confirms one-shot `uid=0` execution with zero side effects. The Dev Mode
shell itself stays `uid=5965`.

## Stage 1 — install Homebrew Channel

1. Serve the payload tree and launch the page:

   ```sh
   npx --yes --package @webos-tools/cli ares-launch --device <device> \
     com.webos.app.tinybrowser \
     -p '{"contentTarget":"http://<lan-host>:18080/index.html"}'
   ```

2. The page downloads `install.manifest.json`, `install.service`,
   `install-hbchannel.sh`, `autoroot.sh`, `hbchannel.ipk` into
   `/media/internal/downloads`, registers the manifests dir, and triggers
   `luna://com.example.install/test`.
3. The root-executed `install-hbchannel.sh` runs SlopBro's `autoroot.sh`
   (with `SCRIPT_DIR`/`IPK_SRC` pointing at the downloads, flags
   `--curl-insecure --leave-script`), which:
   - creates the `/var/luna/preferences/devmode_enabled` directory,
   - restarts `appinstalld`,
   - installs the HBC IPK via
     `luna://com.webos.appInstallService/dev/install`,
   - runs HBC's `elevate-service` (LS2 elevation).

Verify from the Dev Mode shell: the HBC service directory exists under
`/media/developer/apps/usr/palm/services/` and `/tmp/root-install.log` shows
`id` lines with `uid=0` before and after.

## Stage 2 — remove the Dev Mode app

Reload the page with the trigger
`luna://com.webos.appInstallService/dev/remove` and payload
`{"id":"com.palmdts.devmode","subscribe":true}`. (This is the standard
warning from every rooting guide: the Dev Mode app must not remain installed
once rooted.)

## Stage 3 — persistence

The classic persistence hook `start-devmode.sh` does not exist in this C6's
`com.palmdts.devmode` package, which is why a stock rooter alone can report
success and still lose root on reboot here. What does persist:
`org.webosbrew.hbchannel`'s own Activity Manager registration. Reload the
page with the trigger
`luna://org.webosbrew.hbchannel.service/registerActivity`.

## Reboot and verify

```sh
ssh root@<tv-ip> id
# uid=0(root) gid=0(root) groups=0(root),10(wheel),506(pulse-access),509(se),777(crashd),996(lpadmin)
```

HBC's `/var/lib/webosbrew/startup.sh` re-establishes root (SSH via dropbear,
key-only) at every boot. Immediately after: add your SSH key if needed,
disable telnet, and follow [post-root.md](post-root.md).

## Cleanup

Remove the exploit leftovers once persistence is confirmed — keep the HBC
app/service directories and `/var/lib/webosbrew/startup.sh`:

```sh
ssh root@<tv-ip> 'rm -f /media/internal/downloads/{install.manifest.json,install.service,install-hbchannel.sh,autoroot.sh,hbchannel.ipk}'
```

## Credits

- [SlopBro](https://github.com/throwaway96/slopbro) (throwaway96, AGPL v3+)
  for `autoroot.sh` and the issue #73 route discussion.
- [webosbrew](https://github.com/webosbrew) for Homebrew Channel and the
  root stack this builds on.
