# Agents.md - DevContainer Features Project Documentation

**Last updated:** January 20, 2026

## 📋 Project Summary

This repository contains a collection of **DevContainer Features** developed and maintained by **helpers4**. These features are published on GitHub Container Registry (`ghcr.io/helpers4/devcontainer-features/`).

## 🏗️ Project Structure

```
devcontainer-features/
├── src/                              # Features source code
│   ├── angular-dev/                  # Angular development environment
│   │   ├── devcontainer-feature.json # Metadata and options
│   │   ├── install.sh                # Installation script
│   │   └── README.md                 # Documentation
│   ├── git-absorb/                   # git-absorb feature
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── local-mounts/                 # Local dev files mount
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   └── shell-history-per-project/    # Shell history feature
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/                             # Tests for each feature
│   ├── angular-dev/test.sh
│   ├── git-absorb/test.sh
│   ├── local-mounts/test.sh
│   └── shell-history-per-project/test.sh
├── .github/
│   ├── agents.md                     # This file
│   └── copilot-instructions.md       # Copilot instructions (empty)
├── LICENSE                           # AGPL-3.0 License
├── LOCAL_USAGE.md                    # Local usage documentation (empty)
└── README.md                         # Main documentation
```

## 🧩 Available Features

### 1. shell-history-per-project (v0.0.5)
**Description:** Persists shell history per project with automatic detection of available shells.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `shell` | enum | `auto` | Shell to configure (`auto`, `zsh`, `bash`, `fish`) |
| `historyDirectory` | string | `/workspaces/.shell-history` | Persistence directory |
| `maxHistorySize` | string | `10000` | Maximum number of entries |

**Features:**
- Auto-detection of available shells
- Multi-shell support (zsh, bash, fish)
- Symbolic links to persistent history files
- Automatic shell options configuration (SHARE_HISTORY, HIST_IGNORE_DUPS, etc.)

---

### 2. git-absorb (v0.0.2)
**Description:** Installs git-absorb, a tool to automatically absorb staged changes into their logical commits.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `latest` | Version to install |

**Features:**
- Download from GitHub releases (tummychow/git-absorb)
- Multi-architecture support (x86_64, aarch64)
- Installation in `/usr/local/bin/`
- Git subcommand integration

---

### 3. local-mounts (v1.0.0)
**Description:** Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `node` | The username in the container to mount files for |

**Features:**
- Git configuration mounting (~/.gitconfig)
- SSH keys for Git operations and remote connections (~/.ssh)
- GPG keys for commit signing (~/.gnupg)
- npm authentication for private registries (~/.npmrc)
- Configurable target username

---

### 4. angular-dev (v1.0.0)
**Description:** Angular-specific development environment with port forwarding, VS Code extensions, and CLI autocompletion.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installCli` | boolean | `false` | Install Angular CLI globally |

**Features:**
- Port 4200 forwarding for Angular dev server
- VS Code extensions for Angular development (7 extensions)
- CLI autocompletion for zsh and bash
- Optional Angular CLI installation

## 🔧 Common Technical Patterns

### Installation Scripts
All installation scripts follow this pattern:
1. Root privileges verification
2. Automatic non-root user detection
3. Dependencies installation via apt
4. Architecture detection
5. Download from GitHub releases
6. Installation in `/usr/local/bin/`
7. Installation verification
8. Cleanup (trap cleanup)

### Tests
Tests use:
- `set -e` for exit on error
- `dev-container-features-test-lib` (optional)
- Manual checks with emoji messages (✅/❌)

## 📦 Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer-features/shell-history-per-project:0": {},
        "ghcr.io/helpers4/devcontainer-features/git-absorb:0": {},
        "ghcr.io/helpers4/devcontainer-features/local-mounts:1": {},
        "ghcr.io/helpers4/devcontainer-features/angular-dev:1": {}
    }
}
```

## 🧪 Test Commands

```bash
# Test a specific feature
devcontainer features test --features shell-history-per-project
devcontainer features test --features git-absorb
devcontainer features test --features local-mounts
devcontainer features test --features angular-dev
```

## 📝 Notes for AI Agents

### Language
**Everything in this project must be in English:**
- Code and variable names
- Comments
- Commit messages
- Documentation (README, CHANGELOG, etc.)
- Error messages and logs
- Pull request titles and descriptions

### Conventions to Follow
- **License:** AGPL-3.0 (mandatory comment at the top of scripts)
- **Copyright:** `Copyright (c) 2025 helpers4`
- **Shells:** Bash scripts with `set -e`
- **Architecture:** x86_64 and aarch64 support mandatory
- **Installation:** Target `/usr/local/bin/`

### Commit Convention
This project follows [Conventional Commits](https://www.conventionalcommits.org/) with emoji icons between the scope and the message.

**Format:** `<type>(<scope>): <emoji> <description>`

**Examples:**
- `feat(git-absorb): ✨ add version selection option`
- `fix(shell-history): 🐛 fix symlink creation for fish`
- `docs(readme): 📝 update installation instructions`
- `chore: 🔧 update dependencies`
- `refactor(install): ♻️ simplify architecture detection`
- `test(git-absorb): ✅ add integration tests`

**Common emojis:**
| Emoji | Type | Description |
|-------|------|-------------|
| ✨ | feat | New feature |
| 🐛 | fix | Bug fix |
| 📝 | docs | Documentation |
| ♻️ | refactor | Code refactoring |
| ✅ | test | Tests |
| 🔧 | chore | Maintenance |
| 🗑️ | remove | Removal |
| 🚀 | perf | Performance |

### Workflow Guidelines
- **Intermediate commits:** Do not hesitate to make intermediate commits when performing many tasks. This helps track progress and makes it easier to review changes.
- **Never push for intermediate human review:** Do not push the branch for intermediate human review. Only push when the work is complete and ready for final review.

### Adding a New Feature
1. Create `src/<feature-name>/devcontainer-feature.json`
2. Create `src/<feature-name>/install.sh`
3. Create `src/<feature-name>/README.md`
4. Create `test/<feature-name>/test.sh`
5. Update main `README.md`
6. Update this `agents.md` file

### Dependencies
All features declare `installsAfter: ["ghcr.io/devcontainers/features/common-utils"]`

---

*This file is intended to be read and updated by AI agents working on this project.*
