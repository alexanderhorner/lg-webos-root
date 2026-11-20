# AGENTS.md

Guidance for coding agents working in this repository.

## Read order

1. [docs/safety.md](docs/safety.md) — the hard rules (never write to or
   remount-rw system partitions, never `chattr +i`, no firmware flashing).
2. [docs/rooting.md](docs/rooting.md) — how the route works and the
   stage-by-stage reproduction guide (probe → install → dev-remove →
   persist → reboot → clean up), including verification at each stage.
3. [payload/README.md](payload/README.md) — the payload tree, the two
   companions to fetch (SlopBro `autoroot.sh`, HBC IPK), how to serve it,
   and the three trigger values.

## By task

- Reproduce the root → docs/rooting.md + payload/README.md
- Understand or audit the running setup → docs/post-root.md
- Unroot or assess brick risk → docs/safety.md

## Non-negotiables

- Run the harmless probe stage first; verify each stage before the next.
- Stage 2 (removing the Dev Mode app) is one-way — it ends all `ares-*`
  access.
- Judge success by log files and on-TV state, never by luna call output.
