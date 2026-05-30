<h1 align="center">helpers4 — DevContainer Features</h1>

<p align="center">
  <strong>Production-ready DevContainer Features for instant, reproducible development environments.</strong>
</p>

<p align="center">
  <a href="https://github.com/helpers4/devcontainer/blob/main/LICENSE"><img src="https://img.shields.io/github/license/helpers4/devcontainer?color=blue" alt="license" /></a>
  <a href="https://github.com/helpers4/devcontainer"><img src="https://img.shields.io/github/last-commit/helpers4/devcontainer" alt="last commit" /></a>
  <a href="https://containers.dev/features"><img src="https://img.shields.io/badge/devcontainer-features-blue?logo=visual-studio-code&logoColor=white" alt="DevContainer Features" /></a>
</p>

---

## Overview

This repository contains a collection of DevContainer Features developed and maintained by the helpers4 organization. All features are published to the GitHub Container Registry and can be referenced directly in any `devcontainer.json`.

```
ghcr.io/helpers4/devcontainer/<feature-name>
```

## Features

### vite-plus

Complete Vite+ toolchain setup with VS Code extensions (Oxc, Vitest), optimized configuration, and optional global CLI tools. Perfect for modern web development with React, Vue, Svelte, and more.

**Key benefits:**
- Pre-configured Oxc formatter/linter (100x faster than ESLint)
- Vitest test explorer integration
- Smart defaults for Vite+ development
- Global Oxc CLI installation option
- Project setup helper command
- Supports all Vite-compatible frameworks

[📖 Documentation](./src/vite-plus/README.md)

### package-auto-install

Automatically detects and runs npm/yarn/pnpm install in non-interactive mode after container creation. Handles corepack setup for Node 24+ and intelligently detects the package manager from package.json or lockfiles.

**Key benefits:**
- Automatic package manager detection from package.json or lockfiles
- Corepack support for Node 24+ (auto-installs if needed)
- Non-interactive mode (CI=true) prevents prompts
- Smart command selection (npm ci, pnpm --frozen-lockfile, yarn --immutable)
- Eliminates need for manual postCreateCommand

[📖 Documentation](./src/package-auto-install/README.md)

### pnpm-store

Configures a shared pnpm content-addressable store on the **same filesystem as your code**, so pnpm's hardlinks work and no stray `.pnpm-store` folders pollute your repos. A safer alternative to Docker-volume-based store sharing, which breaks hardlinking in bind-mounted workspaces.

**Key benefits:**
- Keeps the pnpm store on the same filesystem as bind-mounted repos
- No `.pnpm-store` clutter inside your projects
- Shares the store across every repo and across rebuilds
- Fail-fast cross-device guard with an actionable fix message
- Writes `store-dir` to `~/.npmrc`; works with any pnpm install

[📖 Documentation](./src/pnpm-store/README.md)

### angular-dev

Angular-specific development environment with VS Code extensions and CLI autocompletion.

**Key benefits:**
- Essential VS Code extensions for Angular development
- CLI autocompletion for zsh and bash
- Optional Angular CLI installation
- Ready-to-use Angular development setup

[📖 Documentation](./src/angular-dev/README.md)

### shell-history-per-project

Persist shell history per project by automatically detecting and configuring all available shells (zsh, bash, fish). Supports auto-detection or manual shell selection.

**Key benefits:**
- Per-project history isolation
- Persistent across container rebuilds
- Multiple shell support (zsh, bash, fish)
- Team collaboration friendly
- Clean separation between personal and project commands

[📖 Documentation](./src/shell-history-per-project/README.md)

### git-absorb

Installs git-absorb, a tool that automatically absorbs staged changes into their logical commits. Like 'git commit --fixup' but automatic.

**Key benefits:**
- Automatic fixup commits for staged changes
- Multi-architecture support (x86_64, aarch64)
- Git subcommand integration
- Lightweight single binary installation
- Perfect for cleaning up commit history

[📖 Documentation](./src/git-absorb/README.md)

### dotfiles-sync

Syncs local Git, SSH, GPG, and npm configuration files into the devcontainer. Works on macOS, Linux, Windows (WSL), and GitHub Codespaces. Uses a merge strategy — never overwrites existing values.

**Key benefits:**
- Git configuration, SSH keys, GPG keys, and npm auth synced automatically
- Merge strategy: safe to use alongside Codespaces native auth
- Environment-aware: detects macOS, Linux, WSL, and Codespaces
- SSH agent forwarding with runtime detection and fallback chain
- Successor to `local-mounts`

[📖 Documentation](./src/dotfiles-sync/README.md)

### local-mounts *(removed)*

> Replaced by `dotfiles-sync`. Use `ghcr.io/helpers4/devcontainer/dotfiles-sync:1` — options and behavior are fully compatible.

### essential-dev

Core development environment with Git visualization, Markdown support, and essential editor enhancements. For GitHub tooling (gh CLI, Copilot, PR & Issues), use `github-dev`.

**Key benefits:**
- Git history, graph visualization, and conventional commits support
- Complete Markdown support with preview and linting
- Multi-cursor, code comparison, and local file history
- File format support (YAML, JSON, CSV, XML, Makefile)
- Works out-of-the-box with zero configuration

[📖 Documentation](./src/essential-dev/README.md)

### github-dev

GitHub CLI (`gh`) and GitHub VS Code extensions (Copilot, Copilot Chat, Pull Requests & Issues, GitHub Actions, RemoteHub).

**Key benefits:**
- `gh` CLI for PRs, issues, releases, and Actions runs from the terminal
- Streamlined GitHub workflows in both the terminal and VS Code
- GitHub Copilot and Copilot Chat for AI assistance
- Pull Requests & Issues panel inside VS Code
- GitHub Actions workflow editor with validation
- RemoteHub to browse remote repos without cloning

[📖 Documentation](./src/github-dev/README.md)

### typescript-dev

TypeScript/JavaScript development setup with indexing, import management, HTML/CSS intelligence, and web tools. Built on top of `essential-dev` for core Git/editor enhancements, with Copilot and PR tooling provided by `github-dev`.

**Key benefits:**
- Latest TypeScript with indexing and import management
- HTML and CSS intelligence with auto-rename
- Automatic import/export management and path aliases
- Web development ready with code generation utilities
- Requires `essential-dev` for core tools

[📖 Documentation](./src/typescript-dev/README.md)

### auto-header

Automatically configures file headers with customizable templates based on project, license, company, and contributors information.

**Key benefits:**
- Two header styles: simple (3 lines) and custom (user-defined)
- Flexible configuration with project name, license, company, and contributors
- Helper script `h4-init-headers` for easy initialization
- SPDX compliant license identifiers
- Works in VS Code with zero configuration needed after setup
- Perfect for maintaining consistent file headers across team projects

[📖 Documentation](./src/auto-header/README.md)

### peon-ping

Installs [peon-ping](https://peonping.com/) for game character voice notifications when your AI coding agent finishes or needs permission. Includes the Peon Pet VS Code extension.

**Key benefits:**
- Sound notifications from 165+ packs (Warcraft, StarCraft, Portal, Zelda…)
- Multi-IDE hooks: Claude Code, Copilot, Cursor, Codex, and more
- Animated Peon Pet sidebar companion in VS Code
- Devcontainer-aware audio relay to host machine
- Non-interactive, idempotent installation

[📖 Documentation](./src/peon-ping/README.md)

## Usage

Features from this repository are available via GitHub Container Registry. Reference them in your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/github-dev:1": {},
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/pnpm-store:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/auto-header:1": {
            "projectName": "my-project"
        },
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {},
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {},
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {}
    }
}
```

## Available Features

| Feature | Description | Documentation |
|---------|-------------|---------------|
| [essential-dev](./src/essential-dev) | Core dev environment with Git visualization, editor tools, and Markdown | [README](./src/essential-dev/README.md) |
| [github-dev](./src/github-dev) | gh CLI, Copilot, PR & Issues, Actions, RemoteHub | [README](./src/github-dev/README.md) |
| [auto-header](./src/auto-header) | Automatic file headers with customizable templates (simple or custom) | [README](./src/auto-header/README.md) |
| [vite-plus](./src/vite-plus) | Complete Vite+ toolchain with Oxc, Vitest, and VS Code integration | [README](./src/vite-plus/README.md) |
| [package-auto-install](./src/package-auto-install) | Automatic package installation with corepack support for Node 24+ | [README](./src/package-auto-install/README.md) |
| [pnpm-store](./src/pnpm-store) | Shared pnpm store on the same filesystem as your code — no stray .pnpm-store in repos | [README](./src/pnpm-store/README.md) |
| [typescript-dev](./src/typescript-dev) | TypeScript/JavaScript dev with indexing and web tools (requires essential-dev) | [README](./src/typescript-dev/README.md) |
| [angular-dev](./src/angular-dev) | Angular development environment with extensions and CLI autocompletion | [README](./src/angular-dev/README.md) |
| [shell-history-per-project](./src/shell-history-per-project) | Per-project shell history persistence with multi-shell auto-detection | [README](./src/shell-history-per-project/README.md) |
| [git-absorb](./src/git-absorb) | Automatic absorption of staged changes into logical commits | [README](./src/git-absorb/README.md) |
| [dotfiles-sync](./src/dotfiles-sync) | Sync local Git, SSH, GPG, and npm config — works on macOS, Linux, WSL, Codespaces | [README](./src/dotfiles-sync/README.md) |
| [peon-ping](./src/peon-ping) | AI agent sound notifications with multi-IDE hooks and Peon Pet extension | [README](./src/peon-ping/README.md) |

## Documentation

Full documentation is available at [**helpers4.dev/devcontainer**](https://helpers4.dev/devcontainer).

## Development

This repository follows the [DevContainer Features specification](https://containers.dev/implementors/features/) and is compatible with the [DevContainer Features distribution](https://containers.dev/implementors/features-distribution/).

### Testing

Features can be tested locally using the [DevContainer CLI](https://github.com/devcontainers/cli):

```bash
devcontainer features test --features shell-history-per-project
```

### Publishing

Features are automatically published to GitHub Container Registry via GitHub Actions when tagged releases are created.

## Contributing

Contributions are welcome! Please follow the established feature structure and test your changes locally before submitting.

1. Fork the repository
2. Create a feature branch
3. Add your feature following the established patterns
4. Test your feature locally
5. Submit a pull request

## License

This project is licensed under the [GNU Lesser General Public License v3.0](LICENSE).

## Acknowledgments

Inspired by the official [DevContainers Features](https://github.com/devcontainers/features) repository and [Stuart Leeks' dev-container-features](https://github.com/stuartleeks/dev-container-features) for the shell-history concept — with the key difference being project-scoped rather than global user history persistence.

## Contributors

<table>
<tr>
    <td align="center" style="word-wrap: break-word; width: 150.0; height: 150.0">
        <a href="https://github.com/baxyz">
            <img src="https://avatars.githubusercontent.com/u/7852177?v=4" width="100;" alt="Bérenger"/>
            <br />
            <sub style="font-size:14px"><b>Bérenger</b></sub>
        </a>
    </td>
</tr>
</table>
