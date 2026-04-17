# AGENTS.md - DevContainer Features

## ⛔ CRITICAL RESTRICTIONS

- **NEVER execute `git push`** - The user will push manually after review
- **NEVER use GPT models** - Use Claude models only (claude-sonnet-4, Claude Opus 4.5)
- **Everything in English** - Code, comments, commits, documentation, logs, PR descriptions

## Organization Context

**helpers4** is a collection of open-source utilities across 5 repos: `typescript`, `devcontainer` (this repo), `action`, `website`, `.github`. All licensed LGPL-3.0.

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/) with a gitmoji between the scope and the description.

**Format:** `<type>(<scope>): <emoji> <description>`

**Scopes:** angular-dev, auto-header, dotfiles-sync, essential-dev, git-absorb, package-auto-install, peon-ping, shell-history-per-project, typescript-dev, vite-plus, CI-CD

| Emoji | Type | Description |
|-------|------|-------------|
| ✨ | feat | New feature |
| 🐛 | fix | Bug fix |
| 📝 | docs | Documentation |
| ♻️ | refactor | Code refactoring |
| ✅ | test | Tests |
| 🔧 | chore | Maintenance |
| 🚀 | perf | Performance |
| 💄 | style | Code style |
| 👷 | ci | CI/CD |
| 📦 | build | Build system |
| ⏪ | revert | Revert |

**Examples:**
- `feat(git-absorb): ✨ add version selection option`
- `fix(local-mounts): 🐛 fix symlink creation`
- `docs(typescript-dev): 📝 update README`
- `chore(CI-CD): 🔧 update dependencies`

---

## This Repository

**Purpose:** DevContainer Features published on GitHub Container Registry (`ghcr.io/helpers4/devcontainer/`).

### Project Structure

```
devcontainer/
├── src/                              # Feature source code
│   ├── essential-dev/                # Core dev environment (Git, Copilot, Markdown)
│   ├── typescript-dev/               # TypeScript/JS dev (requires essential-dev)
│   ├── angular-dev/                  # Angular dev with port forwarding
│   ├── vite-plus/                    # Vite development setup
│   ├── package-auto-install/         # Automatic package installation
│   ├── auto-header/                  # Automatic LGPL-3.0 file headers
│   ├── git-absorb/                   # git-absorb tool installation
│   ├── local-mounts/                 # Mount local Git/SSH/GPG/npm config
│   ├── peon-ping/                    # Health check endpoint
│   └── shell-history-per-project/    # Persistent shell history per project
├── test/                             # One test.sh per feature
├── .github/
│   ├── workflows/                    # CI/CD (test matrix)
│   ├── CONTRIBUTING.md
│   └── DEVELOPMENT.md
├── AGENTS.md                         # This file
├── LICENSE                           # LGPL-3.0
└── README.md
```

### Feature File Structure

Each feature in `src/<name>/` contains:
- `devcontainer-feature.json` — Metadata, options, dependencies
- `install.sh` — Installation script
- `README.md` — Usage documentation

### Installation Script Pattern

All `install.sh` scripts follow:
1. Root privileges verification
2. Automatic non-root user detection
3. Dependencies installation via `apt`
4. Architecture detection (x86_64, aarch64)
5. Download from GitHub releases (when applicable)
6. Installation in `/usr/local/bin/`
7. Installation verification
8. Cleanup (`trap cleanup`)

**Requirements:**
- Bash with `set -e`
- Must support both x86_64 and aarch64
- All features declare `installsAfter: ["ghcr.io/devcontainers/features/common-utils"]`

### Testing

```bash
devcontainer features test --features <feature-name> .  # Test one feature
devcontainer features test .                             # Test all
```

**Base image requirements:**
- Shell features → any base image (debian, ubuntu)
- Node.js features → `mcr.microsoft.com/devcontainers/javascript-node:20`+
- TypeScript features → `mcr.microsoft.com/devcontainers/typescript-node:20`+

### Available Features

| Feature | Version | Description | Dependencies |
|---------|---------|-------------|--------------|
| essential-dev | 1.0.0 | Git, Copilot, Markdown, editor enhancements | — |
| typescript-dev | 1.0.5 | TypeScript/JS dev with import management | essential-dev |
| angular-dev | 1.0.2 | Angular dev, port 4200 forwarding | — |
| vite-plus | — | Vite development setup | — |
| package-auto-install | — | Auto-detect and install packages | — |
| auto-header | — | LGPL-3.0 license headers | — |
| git-absorb | 1.0.2 | git-absorb from GitHub releases | — |
| dotfiles-sync | 1.0.0 | Sync local Git/SSH/GPG/npm config — macOS, Linux, WSL, Codespaces | — |
| peon-ping | — | Health check endpoint | — |
| shell-history-per-project | 1.0.2 | Persistent shell history (zsh/bash/fish) | — |

### CI/CD Workflows

| Workflow | Trigger | Jobs |
|----------|---------|------|
| `pr-validation.yml` | Pull request → main | conventional-commits, test-features (matrix), shellcheck, pr-comment |
| `test.yml` | Push → main | Feature tests matrix |
| `release.yml` | Published release | Publish features to GHCR |

- **conventional-commits** — Validates PR commit messages against conventional commit format
- **test-features** — Matrix of 16 feature/baseImage combos (`devcontainer features test`)
- **shellcheck** — Lints all `install.sh` scripts with ShellCheck
- **pr-comment** — Posts/updates a status summary comment on the PR

### Adding a New Feature

1. Create `src/<feature-name>/devcontainer-feature.json`
2. Create `src/<feature-name>/install.sh`
3. Create `src/<feature-name>/README.md`
4. Create `test/<feature-name>/test.sh`
5. Update main `README.md`
6. **Update `.github/workflows/pr-validation.yml`** — Add feature to test matrix with appropriate base image
7. **Update `.github/workflows/test.yml`** — Add feature to test matrix
8. Update this `AGENTS.md` (scopes + features table)

### Usage

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
    "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
    "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
    "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
    "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
    "ghcr.io/helpers4/devcontainer/local-mounts:1": {},
    "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {}
  }
}
```

### License Header (required on all scripts)

```bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
```

## Repository Links

- TypeScript: https://github.com/helpers4/typescript
- DevContainer: https://github.com/helpers4/devcontainer
- Actions: https://github.com/helpers4/action
- Website: https://github.com/helpers4/website
- Organization: https://github.com/helpers4

## Questions?

If you need clarification on any aspect, open an issue or comment on the PR. We're here to help!
