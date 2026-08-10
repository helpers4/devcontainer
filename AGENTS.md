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
| `helpers4-common` | 1.0.0 | Bootstrap: jq + `common.sh` (user detection, apt helpers) — all features depend on this |
| `essential-dev` | 1.0.2 | Git visualization, editor enhancements, Markdown |
| `github-dev` | 1.0.3 | gh CLI, Copilot Chat, PR/Issues/Actions extensions |
| `copilot-dev` | 1.0.1 | Copilot Chat + AI instructions (commits, PRs, code review) |
| `claude-dev` | 1.0.5 | Claude Code extension + `~/.claude` bind-mount (credentials + memory persist) |
| `mistral-dev` | 1.0.3 | Mistral Vibe extension + `~/.vibe` bind-mount |
| `nub` | 1.0.0 | Fast TS/JS/script runner on top of existing node+package-manager (dependsOn node) |
| `typescript-dev` | 1.0.5 | TS/JS dev, import management (dependsOn essential-dev) |
| `angular-dev` | 1.0.6 | Angular dev, port 4200 |
| `vite-plus` | 1.0.3 | vp CLI, Oxlint/Oxfmt, Vitest |
| `package-auto-install` | 1.0.9 | Auto-detect and install packages (npm/yarn/pnpm/nub) |
| `playwright-dev` | 1.0.1 | Playwright OS deps (Chromium/Firefox/WebKit) + shared browser-binary volume + VS Code extension |
| `pnpm-store` | 1.0.4 | Shared pnpm store via Docker named volume (dependsOn helpers4-common) |
| `auto-header` | — | LGPL-3.0 license headers |
| `git-absorb` | 1.0.7 | git-absorb from GitHub releases |
| `dotfiles-sync` | 1.0.8 | Sync Git/SSH/GPG/npm/gh config from host |
| `peon-ping` | 1.0.5 | AI agent sound notifications |
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

**Verify `version` after merge, not just before.** `version-bump-check` only
validates the PR branch — it can't catch a bump getting lost or reverted
during the merge itself. PR#52 is a real example: correctly bumped across
three commits on the branch, landed back at the old version on `main` after
merge, root cause never pinned down. After merging anything that touches a
`devcontainer-feature.json`, diff `origin/main` against the branch's last
commit for that file before trusting it.

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
  The fix is documenting a required `initializeCommand` in the feature's
  README instead — see `claude-dev` or `mistral-dev`.
- **"Out-of-the-box" for a mount-dependent feature means one documented
  `initializeCommand` line, not zero-config.** Don't chase a silent fix for a
  feature with a hard mount dependency — document the line. If a feature can
  tolerate a missing source at the file level (lots of small files, like
  `dotfiles-sync`), staging into `/mnt/h4dotfiles` and merging at
  `postStartCommand` is safer than a hard mount — but the staged mount still
  needs its own source to exist first, so this only helps once that's true.
- **Cloud environments (Codespaces, Gitpod, DevPod-remote) need the same
  `initializeCommand` as local.** `${localEnv:HOME}` resolves against
  whatever machine orchestrates the build — on Codespaces/Gitpod that's the
  cloud VM, not the user's laptop — so a mount source can be just as missing
  there. Don't write cloud handling that only covers what gets synced
  (protected keys, GPG skip) without covering whether the mount succeeds at
  all; see `dotfiles-sync`'s Codespaces/Gitpod/DevPod README sections. There's
  an open upstream proposal for an `optional: true` mounts flag
  (`devcontainers/spec#132`) that would fix this properly — not merged yet.
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
