# Rooting

## Context

The jsserver root route (patched October 2026) no longer works on this
firmware (`43.21.98`). The route that worked uses the **Luna bus manifest
loader**: webOS lets bus clients register a *manifests directory*, and
services declared in a registered manifest run their `Exec` as root. A stock
app whose web process may call the bus — here `com.webos.app.tinybrowser` —
plus the download manager is enough to plant and register such a manifest.

Everything below runs from a page loaded inside the TV's stock tinybrowser,
served from a machine on the same LAN.

## Prerequisites

- A TV on webOS 11.2.0 / firmware 43.21.98 (the primitives are long-standing
  webOS APIs, but this exact combination is what was verified).
- A machine on the same LAN serving a static page and files over HTTP.
- The Homebrew Channel IPK from
  [webosbrew/webos-homebrew-channel](https://github.com/webosbrew/webos-homebrew-channel/releases).

## The chain

1. **Launch the browser at your page.** Launch `com.webos.app.tinybrowser`
   with a `contentTarget` pointing to the LAN-hosted page.
2. **Place the payload files.** From that page, call
   `luna://com.webos.service.downloadmanager/download` to place three files
   under `/media/internal/downloads`:
   - a manifest (JSON) declaring a service,
   - a service file for that manifest,
   - the script the service file executes.
3. **Register the manifest.** Call
   `luna://com.webos.service.bus/addManifestsDir` with
   `{"prefix":"/media/internal/downloads","dirpath":"."}`.
4. **Trigger the service.** Calling the declared service runs its `Exec` as
   `uid=0`.
5. **Install and persist.** From that root execution:
   - install Homebrew Channel (app + elevated service),
   - remove the removable Developer Mode app,
   - register HBC's persistent Activity Manager autostart
     (`registerActivity`).
6. **Reboot.** HBC re-establishes root access (telnet/SSH) at every boot via
   `/var/lib/webosbrew/startup.sh`.

## Constraints and details learned

- The manifest is JSON and points to the separate service file; it does not
  inline the command.
- The service file must invoke `/bin/sh` — downloaded files do not carry the
  executable permission.
- Manifest services are transient: a new manifest ID is needed after firmware
  or service restarts.
- On this build `com.palmdts.devmode` did not contain the classic
  `start-devmode.sh`, so the stock dev-mode installer alone did not establish
  persistence. HBC's `registerActivity` route did.
- The exact payload files were deleted after use and are not reproduced here;
  the format requirements above are what mattered.

## Verify persistence

After a reboot, SSH in and confirm root:

```sh
ssh root@<tv-ip> id
# uid=0(root) gid=0(root) groups=0(root),10(wheel),506(pulse-access),509(se),777(crashd),996(lpadmin)
```

Then lock in key-only SSH (see [post-root.md](post-root.md)) before changing
anything else.

## Cleanup

Remove the exploit leftovers once persistence is confirmed — keep the HBC
app/service directories and `/var/lib/webosbrew/startup.sh`:

```sh
ssh root@<tv-ip> 'rm -f /media/internal/downloads/{manifest.json,service,script,hbchannel.ipk}'
```

(Use whatever names your run placed there.)
