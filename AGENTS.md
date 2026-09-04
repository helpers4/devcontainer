# AGENTS.md — devcontainer

→ [Org-wide rules](https://github.com/helpers4/.dev/blob/main/AGENTS.md): restrictions · commit format · license headers

## This Repository

**Purpose:** DevContainer Features published to `ghcr.io/helpers4/devcontainer/<name>`.

```text
src/<feature>/
├── devcontainer-feature.json  # id, version, options, mounts, postStartCommand, customizations
├── install.sh                 # runs as root at build time
└── README.md
test/<feature>/test.sh
```

**install.sh pattern:** `set -euo pipefail` · root check · `h4_detect_user` / `h4_resolve_home` from `helpers4-common` · apt deps · arch detection (x86_64/aarch64) · install to `/usr/local/bin/` · `trap cleanup EXIT`

**Testing:**

```bash
devcontainer features test --features <name> .
devcontainer features test .
```

**Available features:**

| Feature | Ver | Description |
| ------- | --- | ----------- |
| `helpers4-common` | 1.0.1 | Bootstrap: jq + `common.sh` (user detection, apt helpers) — all features depend on this |
| `essential-dev` | 1.0.9 | Git visualization, editor enhancements, Markdown |
| `github-dev` | 1.0.5 | gh CLI, Copilot Chat, PR/Issues/Actions extensions |
| `copilot-dev` | 1.0.3 | Copilot Chat + AI instructions (commits, PRs, code review) |
| `claude-dev` | 1.0.8 | Claude Code extension + CLI + `~/.claude` named-volume persistence (credentials + memory) |
| `mistral-dev` | 1.0.6 | Mistral Vibe extension + `~/.vibe` named-volume persistence |
| `cline-dev` | 1.0.0 | Cline extension (`saoudrizwan.claude-dev`) + optional CLI, no credential persistence |
| `nub` | 1.0.0 | Fast TS/JS/script runner on top of existing node+package-manager (dependsOn node) |
| `typescript-dev` | 1.0.7 | TS/JS dev, import management (dependsOn essential-dev) |
| `angular-dev` | 1.0.6 | Angular dev, port 4200 |
| `vite-plus` | 1.0.7 | vp CLI, Oxlint/Oxfmt, Vitest |
| `package-auto-install` | 1.0.9 | Auto-detect and install packages (npm/yarn/pnpm/nub) |
| `playwright-dev` | 1.0.1 | Playwright OS deps (Chromium/Firefox/WebKit) + shared browser-binary volume + VS Code extension |
| `pnpm-store` | 1.0.7 | Shared pnpm store via Docker named volume (dependsOn helpers4-common) |
| `auto-header` | 1.0.8 | LGPL-3.0 license headers |
| `git-absorb` | 1.0.7 | git-absorb from GitHub releases |
| `dotfiles-sync` | 1.0.8 | Sync Git/SSH/GPG/npm/gh config from host |
| `peon-ping` | 1.0.6 | AI agent sound notifications |
| `shell-history-per-project` | 1.0.7 | Persistent shell history (zsh/bash/fish) |

**Adding a new feature — checklist:**

1. `src/<name>/devcontainer-feature.json` + `install.sh` + `README.md`
2. `test/<name>/test.sh`
3. `scopes.json` → add the feature name ← **PR CI fails without this** (action reads `scopes.json` automatically)
4. `.github/workflows/pr-validation.yml` + `test.yml` → add to test matrix
5. This `AGENTS.md` features table

**Modifying an existing feature — version bump:**

Any change under `src/<name>/` that touches `install.sh`,
`devcontainer-feature.json`, or `test/<name>/test.sh` must bump that
feature's `version` field (patch by default, minor/major when warranted) —
`release.yml` only tags and publishes a feature whose `version` changed
between the base branch and HEAD, so an unbumped change to something that
actually ships silently never gets published. Bump it **once per branch**:
if the version on the branch already differs from `main`'s, a further commit
on that same branch/PR must *not* bump it again — check the diff against
`main` first, don't bump reflexively on every commit.

A **README-only** change doesn't require a bump — nothing about what ships
in the image changes. It's still worth bumping when the doc fix is
safety-relevant (e.g. a corrected `initializeCommand` requirement, like
`dotfiles-sync` v1.0.8), since `release.yml`'s version-diff gate is also
what triggers the website docs rebuild — an unbumped README fix never
reaches the published site. Judgment call, not enforced either way.

Enforced by the `version-bump-check` job in `pr-validation.yml`: it fails the
PR if a touched feature's `version` is unchanged from `main` *and* something
other than `src/<name>/README.md` changed under `src/<name>/` or
`test/<name>/`. It's a blocking check only — it never commits a bump on your
behalf (deliberately:
no bot commits, no push-permission/fork edge cases, consistent with how
`conventional-commits` already works in this repo). Bump the version
yourself and push again.

**A lost version bump after merge gets flagged, not just caught before merge.**
`version-bump-check` only validates the PR branch — it can't catch a bump
getting lost or reverted during the merge itself. PR#52 is a real example:
correctly bumped across three commits on the branch, landed back at the old
version on `main` after merge, root cause never pinned down. `release.yml`'s
`detect` job now emits a `::warning::` when a feature's manifest changed in
a push to `main` but its `version` field didn't move — the same signal
`version-bump-check` uses, just re-checked against what actually landed.
It's a warning, not a blocking failure (failing `detect` would also block
publishing every *other* feature bumped in the same push), so still worth a
manual `diff origin/main` against the branch's last commit if something
looks off — the warning just means you don't have to remember to check
every single time.

**License header (all scripts):**

```bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
```

## Design constraints for features

These are hard requirements, not style preferences — violating them breaks the
container for users, sometimes silently.

- **A `mounts` entry fails the whole container if the host source doesn't
  exist — file or directory, no exceptions.** The devcontainers CLI uses
  `docker run --mount type=bind,...`, which errors out on a missing source
  instead of creating it. No feature script can catch this — mounts resolve
  before `install.sh` / `postCreateCommand` / `postStartCommand` ever run.
- **A Feature's own `initializeCommand` can't work around that — it's
  ignored.** Only the consumer's top-level `devcontainer.json` gets its
  `initializeCommand` executed; a Feature manifest's own `initializeCommand`
  is silently dropped (tried on `claude-dev` v1.0.3, reverted as dead code).
  For a bind-mount-dependent feature, document a required `initializeCommand`
  in the README instead — see `dotfiles-sync`. A named-volume mount sidesteps
  this need entirely (see below) — no host path has to exist beforehand.
- **"Out-of-the-box" for a mount-dependent feature means one documented
  `initializeCommand` line, not zero-config.** Don't chase a silent fix for a
  feature with a hard mount dependency — document the line. If a feature can
  tolerate a missing source at the file level (lots of small files, like
  `dotfiles-sync`), staging into `/mnt/h4dotfiles` and merging at
  `postStartCommand` is safer than a hard mount — but the staged mount still
  needs its own source to exist first, so this only helps once that's true.
- **Cloud environments (Gitpod, DevPod-remote) need the same
  `initializeCommand` as local.** `${localEnv:HOME}` resolves against
  whatever machine orchestrates the build — on Gitpod/DevPod-remote that's the
  cloud VM, not the user's laptop — so a mount source can be just as missing
  there. Don't write cloud handling that only covers what gets synced
  (protected keys, GPG skip) without covering whether the mount succeeds at
  all; see `dotfiles-sync`'s Codespaces/Gitpod/DevPod README sections. There's
  an open upstream proposal for an `optional: true` mounts flag
  (`devcontainers/spec#132`) that would fix this properly — not merged yet.
- **GitHub Codespaces doesn't support host bind-mounts at all** — not a
  missing directory an `initializeCommand` could pre-create, a hard platform
  limitation ("Mounting the local file system is not supported in GitHub
  Codespaces" — [VS Code docs](https://code.visualstudio.com/remote/advancedcontainers/add-local-file-mount)).
  `${localEnv:HOME}` can resolve to an empty string there, turning a mount
  source like `${localEnv:HOME}/.claude` into the literal path `/.claude`,
  which doesn't exist, and failing the whole codespace build
  (`helpers4/devcontainer#66`). The fix is a Docker named volume instead of a
  bind-mount, not a smarter `initializeCommand`.
- **A named volume that needs to stay shared across every local project for
  one identity (credentials, not a per-project cache) should be scoped by
  `${localEnv:USER}`**, e.g. `helpers4-claude-credentials-${localEnv:USER}`
  (see `claude-dev`, `mistral-dev`). This is different from the
  `${devcontainerId}`-scoped volumes below (`pnpm-store`, `playwright-dev`),
  which intentionally isolate per project — right for a cache, wrong for an
  identity a bind-mount used to share across every project. Docker creates a
  named volume automatically, so this also has none of a bind-mount's
  missing-source crash risk on Codespaces. One tradeoff: on a host where
  `$USER` is unset, everyone missing it shares one volume — irrelevant on a
  personal machine or an already-isolated Codespaces VM, worth knowing on a
  shared multi-user build server.
- **Docker creates a fresh named volume root-owned — the non-root
  `postStartCommand`/`postCreateCommand` user can't write to it until
  something chowns it.** Missed on `claude-dev`/`mistral-dev` when they first
  switched from a bind-mount to a volume (v1.0.6/v1.0.4): the generated
  credentials script symlinked `~/.claude`/`~/.vibe` straight into the
  root-owned volume with no chown step, so every write under it (session
  state, settings, memory) failed with `EACCES` for the container's real
  user. `pnpm-store`'s guard script already had this solved —
  `stat -c '%u'` the volume, `sudo chown -R "$(id -u):$(id -g)"` it if it
  doesn't already belong to the current user (skip the chown when it does;
  a recursive chown on a populated, shared-across-rebuilds volume isn't
  free) — `claude-dev`/`mistral-dev` v1.0.8/v1.0.6 copy that pattern. Any
  new named-volume feature needs this same chown step, not just the mount.
- **`devcontainer-feature.json` must be plain JSON — no `//` comments.**
  `devcontainers/action` parses it with `JSON.parse`, which chokes on JSONC —
  broke the release workflow once (commit `4e6e5ee`). Put rationale in the
  README or the install script instead.
- **Must work inside a VS Code multi-root `.code-workspace`** — this repo's
  own devcontainer bundles 6 sibling repos this way. Treat it as the normal
  case, not an edge case.
- **Dedicated AI-tool features cover three things**: CLI install, IDE
  extension, settings — see `claude-dev`, `mistral-dev`, `copilot-dev`.
  `github-dev` reimplements `gh` CLI install rather than depending on an
  upstream feature because no existing feature bundles the CLI and the IDE
  extension together.
- **A shared named `volume` mount needs `${devcontainerId}` in its source**
  — see `pnpm-store` and `playwright-dev`. It's derived from the workspace's
  local folder path, so it stays stable across rebuilds of one workspace but
  won't collide with an unrelated project on the same machine. Volumes don't
  have the missing-source crash risk bind mounts do (Docker creates them),
  but they do need this scoping.
