# Roadmap / Ideas — devcontainer

Backlog of future work — not an active plan like the (now-removed) audit `TODO.md` was.
Items here are ideas or known gaps, not yet scoped or scheduled.

- **OpenSSF Scorecard.** Already set up in `helpers4/typescript`
  (`.github/workflows/scorecard.yml` + badge in `README.md`) — replicate the same workflow
  here: weekly cron + `workflow_dispatch`, `ossf/scorecard-action`, SARIF upload to code
  scanning, badge linking to `securityscorecards.dev/viewer/?uri=github.com/helpers4/devcontainer`.
  Needs a `SCORECARD_TOKEN` repo secret (check whether the typescript repo's can be reused
  org-wide or if this repo needs its own PAT).

- **`peon-ping`: sound forwarding is broken.** Currently relies on
  `host.docker.internal:19998` for the container → host audio relay (see feature README,
  "Container sends audio requests to `host.docker.internal:19998` automatically. No port
  forwarding configuration needed.") — doesn't actually work right now. Needs investigation:
  confirm whether `host.docker.internal` resolves in the affected environments (Linux Docker
  without Docker Desktop doesn't get this DNS entry for free), whether the relay listener is
  actually running/reachable, and whether an explicit `appPort`/`forwardPorts` entry is needed
  in the feature or documented as a consumer requirement.

- **`peon-ping`: simplify configuration around a single language/pack choice.** Right now
  config exposes packs, categories, rotation, volume, etc. separately — consider collapsing
  the common case to "pick a pack, pre-configured for you" instead of composing multiple
  options by hand. Reference: [openpeon.com](https://openpeon.com) for how the packs are
  presented there. Needs a concrete design pass before touching `devcontainer-feature.json`'s
  options schema (backward compatibility with existing option names to consider).

- **New feature: `nub`** ([nubjs.com](https://nubjs.com/)) — Rust binary that runs TS/JS
  directly, runs `package.json` scripts and local CLIs faster, and manages Node versions. It is
  explicitly **not a new runtime**: "runs on the node and package manager you already have, no
  lock-in" — it's an acceleration layer on top of the existing node+npm/pnpm/bun setup, not a
  replacement for it. That framing drives the whole strategy below: this is additive, never a
  rip-and-replace of `pnpm-store`/`package-auto-install`/the official `node` feature.

  No VS Code extension (checked). Should be its own feature, not folded into `typescript-dev`
  (IDE-extensions-only today, zero CLI installs — bundling would break that separation) —
  closest precedent is `vite-plus`'s shape (user-space binary + optional
  `installGlobally`/symlink-to-`/usr/local/bin` option) or `git-absorb`'s GitHub-releases
  download pattern; official installer is `curl -fsSL https://nubjs.com/install.sh | bash`,
  no sudo needed, installs to `~/.nub/bin`. Needs `dependsOn`/`installsAfter` on Node the same
  way `playwright-dev` now does (see AGENTS.md "Verify version after merge" incident — that
  PR is also where the dependsOn-node fix pattern to copy lives).

  **Proposed migration strategy for consuming projects** (opt-in, additive, reversible at every
  step — nothing here requires abandoning node/pnpm if `nub` doesn't pan out):

  1. **Ship the feature, opt-in only.** `nub` feature added to the registry; no existing
     `devcontainer.json` changes unless a project explicitly adds it. `dependsOn` the official
     `node` feature so Node itself stays the single source of truth for the runtime — `nub`
     wraps it, doesn't replace it. Document explicitly in the README: **don't** use
     `nub node install` inside these devcontainers, pin Node via the `node` feature's own
     `version` option instead, to avoid two competing version-selection mechanisms in the same
     container.
  2. **`package-auto-install` gains a `nub` value for `packageManager`**, delegating to
     `nub install` instead of invoking npm/pnpm/yarn directly — safe because `nub install`
     itself detects and delegates to whichever lockfile is present, so this is a thin
     pass-through, not new logic to maintain. Keep `auto`/`npm`/`yarn`/`pnpm` as-is for projects
     that don't opt in.
  3. **Verify `pnpm-store` compatibility before recommending both together.** `pnpm-store`'s
     whole job is a shared content-addressable store via a Docker volume — confirm `nub`
     delegating to the real `pnpm` binary actually respects a custom store-dir the way
     `pnpm-store` sets it up, rather than each pnpm invocation ending up with a different config.
     Don't recommend `nub` + `pnpm-store` together in docs until this is actually confirmed
     working, not assumed.
  4. **Pilot in one real project before wider rollout** — `typescript` is the best candidate
     (heaviest TS build/test iteration loop, so it's where `nub`'s speed claims matter most and
     where compatibility problems would surface fastest). Evaluate for a real period before
     touching other repos' `devcontainer.json`.
  5. **CI is a separate decision, out of this repo's scope.** GitHub Actions runners don't use
     devcontainers, so adopting `nub` there (e.g. via a `setup-nub` action) is independent of
     this feature and needs its own evaluation — don't conflate "devcontainer has nub available"
     with "CI uses nub," they're unrelated changes with different risk profiles.

  Project-level adoption (each repo's own choice, not something the feature can force): replace
  `tsx`/`ts-node` devDependencies with running files via `nub` directly, `npm run`/`pnpm run` →
  `nub run`, `npx` → `nubx`. Document the recommended aliases in the feature's own README once
  scaffolded, rather than trying to rewrite every consuming project's scripts from here.

- **New feature: `python-dev`.** Python-specific dev environment + extensions, following the
  shape of `typescript-dev`/`angular-dev` (dependsOn `essential-dev`, VS Code extensions,
  relevant settings). Check first whether an existing official/community feature
  (`ghcr.io/devcontainers/features/python`) already covers the CLI/interpreter install — if so,
  this feature's job is likely just extensions + settings on top, same pattern as `angular-dev`
  delegating CLI install to `ghcr.io/devcontainers-extra/features/angular-cli`. Use the
  `/add-devcontainer-feature` skill once scoped.
