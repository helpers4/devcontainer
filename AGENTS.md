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
3. `.vscode/settings.json` → add to `conventionalCommits.scopes` ← **PR CI fails without this**
4. `.github/workflows/pr-validation.yml` + `test.yml` → add to test matrix
5. This `AGENTS.md` features table

**License header (all scripts):**

```bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
```
