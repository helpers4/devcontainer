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
| `claude-dev` | 1.0.4 | Claude Code extension + `~/.claude` bind-mount (credentials + memory persist) |
| `mistral-dev` | 1.0.1 | Mistral Vibe extension + `~/.vibe` bind-mount |
| `typescript-dev` | 1.0.5 | TS/JS dev, import management (dependsOn essential-dev) |
| `angular-dev` | 1.0.2 | Angular dev, port 4200 |
| `vite-plus` | 1.0.3 | vp CLI, Oxlint/Oxfmt, Vitest |
| `package-auto-install` | — | Auto-detect and install packages |
| `pnpm-store` | 1.0.4 | Shared pnpm store via Docker named volume (dependsOn helpers4-common) |
| `auto-header` | — | LGPL-3.0 license headers |
| `git-absorb` | 1.0.2 | git-absorb from GitHub releases |
| `dotfiles-sync` | 1.0.2 | Sync Git/SSH/GPG/npm/gh config from host |
| `peon-ping` | 1.0.3 | AI agent sound notifications |
| `shell-history-per-project` | 1.0.2 | Persistent shell history (zsh/bash/fish) |

**Adding a new feature — checklist:**

1. `src/<name>/devcontainer-feature.json` + `install.sh` + `README.md`
2. `test/<name>/test.sh`
3. `scopes.json` → add the feature name ← **PR CI fails without this** (action reads `scopes.json` automatically)
4. `.github/workflows/pr-validation.yml` + `test.yml` → add to test matrix
5. This `AGENTS.md` features table

**Modifying an existing feature — version bump:**

Any change under `src/<name>/` (`install.sh`, `devcontainer-feature.json`,
`README.md`, …) must bump that feature's `version` field (patch by default,
minor/major when warranted) — `release.yml` only tags and publishes a feature
whose `version` changed between the base branch and HEAD, so an unbumped
feature change silently never ships. Bump it **once per branch**: if the
version on the branch already differs from `main`'s, a further commit on that
same branch/PR must *not* bump it again — check the diff against `main`
first, don't bump reflexively on every commit.

Enforced by the `version-bump-check` job in `pr-validation.yml`: it fails the
PR if a touched feature's `version` is unchanged from `main`. It's a blocking
check only — it never commits a bump on your behalf (deliberately: no bot
commits, no push-permission/fork edge cases, consistent with how
`conventional-commits` already works in this repo). Bump the version yourself
and push again.

**License header (all scripts):**

```bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
```

## Design constraints for features

These are hard requirements, not style preferences — violating them breaks the
container for users, sometimes silently.

- **Never rely on a direct `mounts` entry for a host path that might not exist.**
  DevContainer `mounts` are resolved by Docker before any `install.sh` /
  `postCreateCommand` / `postStartCommand` runs. If the host source path is
  missing — file *or* directory — the mount fails and the container fails to
  start. No feature script can catch or work around this after the fact. This
  is why `dotfiles-sync` doesn't bind-mount straight into the final target
  (`~/.gitconfig`, `~/.ssh`, …); it stages into `/mnt/h4dotfiles` and merges at
  `postStartCommand`, tolerating an absent source. Any new feature that needs
  host state (credentials, config dirs) must follow the same staging pattern —
  don't copy `claude-dev`'s/`mistral-dev`'s direct-mount-and-symlink shape
  without first confirming it can't crash on a first-time user who has no
  `~/.claude` / `~/.vibe` yet.
- **Features must work out-of-the-box.** Never require the user to manually
  create a folder or file on the host before first use.
- **Must work inside a VS Code multi-root `.code-workspace`** — this repo's own
  devcontainer bundles 6 sibling repos this way (see the root `.dev/CLAUDE.md`
  workspace layout). Treat this as a standard case, not an edge case.
- **Dedicated AI-tool features must cover three things**: CLI install, IDE
  extension, and settings/configuration — see `claude-dev`, `mistral-dev`,
  `copilot-dev`. `github-dev` intentionally reimplements `gh` CLI install
  rather than depending on an upstream feature, because no known existing
  devcontainer feature bundles the CLI *and* the IDE extension together — that
  bundling is the actual reason this feature exists.
