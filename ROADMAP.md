# Roadmap / Ideas — devcontainer

Backlog of future work — not an active plan like the (now-removed) audit `TODO.md` was.
Items here are ideas or known gaps, not yet scoped or scheduled.

## Resolved

- [x] **`nub` feature.** Shipped as `src/nub/`. Depends on the official `node` feature,
  `installGlobally` option mirrors `vite-plus`. Doesn't set up `nub pm shim` (npm/npx PATH
  interception) — that's a bigger call left to consuming projects.
- [x] **`package-auto-install` + `nub` integration.** `packageManager` gained a `nub` value,
  runs `nub install`. Not part of `auto` detection — nub isn't a lockfile format, so there's
  no real signal to detect it from.
- [x] **`peon-ping`: sound forwarding.** Two separate bugs: the Copilot hooks merge path in
  `install.sh` had a Python syntax error (a dict literal missing its assignment), and the
  README's claim that no port forwarding is needed was wrong on native Linux Docker —
  `host.docker.internal` doesn't resolve there without `runArgs:
  ["--add-host=host.docker.internal:host-gateway"]` in the consumer's `devcontainer.json`.
  Both fixed. Still open: whether the host-side `peon relay` binds to an interface reachable
  from a container — that's the `peon` CLI's own behavior, not something we control.
- [x] **`peon-ping`: pack selection.** `packs` was already a single option; the real friction
  was finding a pack among ~165 in the registry, not configuring one. Pointed the README at
  `peon packs search` and `openpeon.com/packs` instead of adding a redundant preset option.
- [x] **`python-dev` — not building it.** The official `ghcr.io/devcontainers/features/python:1`
  already ships VS Code extensions (pylance, autopep8) and settings on top of the interpreter,
  unlike `angular-cli` which is why `angular-dev` exists as a wrapper. No gap to fill, and no
  repo here uses Python yet.

## Open

- [ ] **`pnpm-store` compatibility with `nub`.** Does `nub` delegating to `pnpm` respect the
  `store-dir` config `pnpm-store` sets up, or does each invocation end up with its own?
  Don't document the pairing as supported until someone's actually run it.

- [ ] **OpenSSF Scorecard.** Not set up anywhere in the org yet — `helpers4/typescript` has
  the workflow file but nothing registered on OpenSSF's side, so there's no working example
  to copy. Wait until that's sorted somewhere first.

- [ ] **`peon-ping` host relay reachability.** Whether the relay is actually reachable (not
  just DNS-resolvable) depends on what interface `peon relay --daemon` binds to on the host.
  Needs a real speaker and a real host to test — see the README's "Verifying it actually
  works" section.
