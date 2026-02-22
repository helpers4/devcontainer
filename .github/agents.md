# Agents.md - DevContainer Project Documentation

**Last updated:** January 20, 2026

## 📋 Project Summary

This repository (`helpers4/devcontainer`) contains a collection of **DevContainer Features** developed and maintained by **helpers4**. These features are published on GitHub Container Registry (`ghcr.io/helpers4/devcontainer/`).

## 🏗️ Project Structure

```
devcontainer/
├── features/                         # Features source code
│   ├── essential-dev/                # Essential dev environment
│   │   ├── devcontainer-feature.json # Metadata and options
│   │   ├── install.sh                # Installation script
│   │   └── README.md                 # Documentation
│   ├── typescript-dev/               # TypeScript/JavaScript development
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── angular-dev/                  # Angular development environment
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── vite-plus/                    # Vite development setup
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── package-auto-install/         # Automatic package installation
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── auto-header/                  # Automatic file headers
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
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
│   ├── essential-dev/test.sh
│   ├── typescript-dev/test.sh
│   ├── angular-dev/test.sh
│   ├── vite-plus/test.sh
│   ├── package-auto-install/test.sh
│   ├── auto-header/test.sh
│   ├── git-absorb/test.sh
│   ├── local-mounts/test.sh
│   └── shell-history-per-project/test.sh
├── .github/
│   ├── agents.md                     # This file
│   ├── DEVELOPMENT.md                # Development instructions
│   ├── CONTRIBUTING.md               # Contributing guidelines
│   └── workflows/                    # CI/CD workflows
├── LICENSE                           # AGPL-3.0 License
├── README.md                         # Main documentation
└── AGENTS.md                         # Agent instructions (from helpers4 root)
```

## 🧩 Available Features

### 1. essential-dev (v1.0.0)
**Description:** Core development environment with Git integration, GitHub Copilot, Markdown support, and essential editor enhancements.

**Features:**
- Git integration (history, graph visualization, PR support, conventional commits)
- GitHub Copilot AI assistance
- Complete Markdown support with preview and linting
- Editor enhancements (multi-cursor, code comparison, local history)
- File format support (YAML, JSON, CSV, XML, Makefile)
- Zero configuration needed

---

### 2. typescript-dev (v1.0.5)
**Description:** TypeScript/JavaScript development setup with indexing, import management, HTML/CSS intelligence, and web tools. Requires `essential-dev`.

**Features:**
- TypeScript with fast indexing and import management
- JavaScript editing with quick fixes and auto-imports
- HTML and CSS intelligence with auto-rename
- Automatic import/export management
- Code generation utilities (quicktype)
- **Dependency:** Requires `essential-dev` feature

---

### 3. shell-history-per-project (v1.0.2)
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

### 4. git-absorb (v1.0.2)
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

### 5. local-mounts (v1.0.4)
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

### 6. angular-dev (v1.0.2)
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

## 🧪 Test Commands

```bash
# Test a specific feature
devcontainer features test --features essential-dev
devcontainer features test --features typescript-dev
devcontainer features test --features vite-plus
devcontainer features test --features package-auto-install
devcontainer features test --features git-absorb
devcontainer features test --features local-mounts
devcontainer features test --features shell-history-per-project
devcontainer features test --features angular-dev
devcontainer features test --features auto-header
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
1. Create `features/<feature-name>/devcontainer-feature.json`
2. Create `features/<feature-name>/install.sh`
3. Create `features/<feature-name>/README.md`
4. Create `test/<feature-name>/test.sh`
5. Update main `README.md`
6. Update this `agents.md` file
7. **IMPORTANT: Update `.github/workflows/test.yml`** - Add the new feature to the test matrix with appropriate base image
   - Shell features: Use any base image (debian, ubuntu, devcontainers/base)
   - Node.js features: Use `mcr.microsoft.com/devcontainers/javascript-node:20` or higher
   - TypeScript features: Use `mcr.microsoft.com/devcontainers/typescript-node:20` or higher
   - Features with mounts: Can test with Node.js base image (mounts are optional)

### Dependencies
All features declare `installsAfter: ["ghcr.io/devcontainers/features/common-utils"]`

---

*This file is intended to be read and updated by AI agents working on this project.*
