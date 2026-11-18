# Payload

The exact files from the working run (2026-11-15), with bus names changed to
generic `com.example.*` ones — the names are arbitrary, any unused bus name
works. Host addresses are relative to wherever the page is served; the
original also logged results back to its LAN host, which is omitted here.

```
index.html                       the page loaded inside com.webos.app.tinybrowser
manifests/install.manifest.json  Luna bus manifest declaring one service
manifests/install.service        D-BUS service file; Exec runs as uid=0
scripts/install-hbchannel.sh     root-stage wrapper around SlopBro's autoroot.sh
scripts/probe.sh                 harmless stage-0 marker: writes date/id/uname
```

Two larger companions are **not** bundled — fetch them into `root/` next to
the page before starting:

- `autoroot.sh` — [SlopBro](https://github.com/throwaway96/slopbro)'s root
  installer (AGPL v3+, © throwaway96). It creates the
  `/var/luna/preferences/devmode_enabled` directory, restarts `appinstalld`,
  installs the Homebrew Channel IPK via
  `luna://com.webos.appInstallService/dev/install`, and runs HBC's
  `elevate-service`. Used flags: `--curl-insecure` (LAN-hosted files) and
  `--leave-script`.
- `hbchannel.ipk` — Homebrew Channel `0.7.3` from the
  [upstream release](https://github.com/webosbrew/webos-homebrew-channel/releases/download/v0.7.3/org.webosbrew.hbchannel_0.7.3_all.ipk)
  (sha256 `d10bf3c753551d7c72fb7a92b20fcd2317e502a220ac668ba8e76f6ea78b363c`).

## Serving

Any static file server on the LAN works:

```sh
cd payload && python3 -m http.server 18080 --bind 0.0.0.0
```

The page's `/log` progress fetches are fire-and-forget; a plain server just
404s them. The original run used a tiny server that also printed those
callbacks and accepted a `POST /report` from `probe.sh` — convenient, not
required.

## The three trigger values

The page registers the manifest dir, then calls one trigger URI. The working
run advanced through three values (one page reload each):

| Run | Trigger (`call(...)`) | Payload | Effect |
|---|---|---|---|
| 1 | `luna://com.example.install/test` | `{}` | Spawns the service `Exec` as `uid=0` → installs HBC (see [rooting.md](../docs/rooting.md)) |
| 2 | `luna://com.webos.appInstallService/dev/remove` | `{'id':'com.palmdts.devmode','subscribe':true}` | Removes the Dev Mode app |
| 3 | `luna://org.webosbrew.hbchannel.service/registerActivity` | `{}` | Registers HBC's Activity Manager autostart — persistence |

Change the `trigger` line in `index.html` between runs. The method name in
run 1 (`/test`) is irrelevant — **any** call to the service name launches the
`Exec`.
