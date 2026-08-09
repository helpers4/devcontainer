# Roadmap / Ideas — devcontainer

Backlog of future work — not an active plan like the (now-removed) audit `TODO.md` was.
Items here are ideas or known gaps, not yet scoped or scheduled.

## Resolved

- [x] **`nub` feature.** Shipped as `src/nub/` — see `AGENTS.md` features table. Followed the
  migration strategy that used to live in this file (now implemented, not just planned):
  `dependsOn` the official `node` feature, `installGlobally` option mirroring `vite-plus`,
  no `nub pm shim`/PATH interception forced on consumers. Verified for real: downloaded and
  ran the actual installer, ran `nub --version`, ran a JS file through `nub`, confirmed the
  `nubx` symlink dispatches correctly.
- [x] **`package-auto-install` + `nub` integration.** `packageManager` gained a `nub` value,
  runs `nub install`. Deliberately excluded from `auto` detection — nub isn't a lockfile
  format, so auto-detecting it would be guessing at intent rather than reading a real signal.
- [x] **`peon-ping`: sound forwarding investigated and partially fixed.** Two distinct real
  bugs found, not one: (1) a genuine `install.sh` Python `SyntaxError` in the Copilot hooks
  merge path, fixed and verified with `python3 -m py_compile` plus a functional test;
  (2) the README's "no port forwarding configuration needed" claim was wrong on native Linux
  Docker — verified empirically from inside a real devcontainer that `host.docker.internal`
  doesn't resolve there without `runArgs: ["--add-host=host.docker.internal:host-gateway"]`
  in the *consumer's* `devcontainer.json` (a Feature can't add `runArgs` itself). Documented
  with concrete manual verification steps. What's **not** verified: whether the host-side
  `peon relay` actually binds to an interface reachable from a container by default — that's
  the upstream `peon` CLI's own responsibility, outside what this repo controls or can test
  without real host audio hardware.
- [x] **`peon-ping`: simplify pack selection — evaluated, no schema change made.** `packs`
  was already a single, simple option; the actual friction was discoverability across ~165
  registry packs, not composition. Added a "Choosing a pack" section pointing at
  `peon packs search` / `openpeon.com/packs` instead of a redundant preset option or a
  hand-maintained pack list that would go stale.
- [x] **`python-dev` — evaluated, decided not to build it.** Checked the official
  `ghcr.io/devcontainers/features/python:1` feature's manifest directly (not assumed): it
  already ships `customizations.vscode.extensions` (`ms-python.python`,
  `ms-python.vscode-pylance`, `ms-python.autopep8`) *and* settings
  (`python.defaultInterpreterPath`, default formatter), on top of the interpreter/pip/dev-tools
  install. Unlike `angular-cli` (CLI-only, no IDE layer — the actual reason `angular-dev`
  exists), there's no gap left for a helpers4 wrapper to fill. Combined with no sibling repo
  in this org currently using Python, building this now would be speculative work solving a
  problem the official feature already solves. Revisit only if a real Python repo shows up
  *and* needs something the official feature genuinely doesn't cover.

## Open

- [ ] **`pnpm-store` compatibility with `nub`** — not yet verified against a real project
  using both together (item 3 of the original nub strategy: does `nub` delegating to `pnpm`
  actually respect the `store-dir`/`storeDir` config `pnpm-store` sets up, or does each `nub`
  invocation end up with a different config?). Don't document the pairing as supported until
  this is confirmed, not assumed.

- [ ] **OpenSSF Scorecard.** Not actually set up anywhere in the org yet — `helpers4/typescript`
  has the workflow file, but nothing is registered/active on OpenSSF's side there either, so
  there's no working reference to copy a working secret/setup from. Holding off here until
  that's sorted out somewhere first, rather than adding a second copy of an inactive workflow.

- [ ] **`peon-ping` host relay reachability.** Even after the `host.docker.internal` DNS fix
  above, whether the relay is actually *reachable* (not just resolvable) depends on what
  interface `peon relay --daemon` binds to on the host — not something this repo controls.
  Needs a real end-to-end test with actual host audio hardware, which nothing in this
  environment can do. See the peon-ping README's "Verifying it actually works" section for
  the manual steps to run interactively.
