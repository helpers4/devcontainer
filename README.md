# DevContainer Features by helpers4

This repository contains a collection of DevContainer Features developed and maintained by helpers4.

Published at: `ghcr.io/helpers4/devcontainer/<feature-name>`

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

[📖 Documentation](./features/vite-plus/README.md)

### package-auto-install

Automatically detects and runs npm/yarn/pnpm install in non-interactive mode after container creation. Handles corepack setup for Node 24+ and intelligently detects the package manager from package.json or lockfiles.

**Key benefits:**
- Automatic package manager detection from package.json or lockfiles
- Corepack support for Node 24+ (auto-installs if needed)
- Non-interactive mode (CI=true) prevents prompts
- Smart command selection (npm ci, pnpm --frozen-lockfile, yarn --immutable)
- Eliminates need for manual postCreateCommand

[📖 Documentation](./features/package-auto-install/README.md)

### angular-dev

Angular-specific development environment with VS Code extensions and CLI autocompletion.

**Key benefits:**
- Essential VS Code extensions for Angular development
- CLI autocompletion for zsh and bash
- Optional Angular CLI installation
- Ready-to-use Angular development setup

[📖 Documentation](./features/angular-dev/README.md)

### shell-history-per-project

Persist shell history per project by automatically detecting and configuring all available shells (zsh, bash, fish). Supports auto-detection or manual shell selection.

**Key benefits:**
- Per-project history isolation
- Persistent across container rebuilds
- Multiple shell support (zsh, bash, fish)
- Team collaboration friendly
- Clean separation between personal and project commands

[📖 Documentation](./features/shell-history-per-project/README.md)

### git-absorb

Installs git-absorb, a tool that automatically absorbs staged changes into their logical commits. Like 'git commit --fixup' but automatic.

**Key benefits:**
- Automatic fixup commits for staged changes
- Multi-architecture support (x86_64, aarch64)
- Git subcommand integration
- Lightweight single binary installation
- Perfect for cleaning up commit history

[📖 Documentation](./features/git-absorb/README.md)

### local-mounts

Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication. Now with proper SSH agent forwarding support.

**Key benefits:**
- Git configuration available inside container
- SSH keys and SSH agent forwarding configured automatically
- GPG keys for commit signing
- npm authentication for private registries
- Fixed SSH_AUTH_SOCK handling for devcontainer compatibility

[📖 Documentation](./features/local-mounts/README.md)

### essential-dev

Core development environment with Git integration, GitHub Copilot, Markdown support, and essential editor enhancements. Perfect base for all development projects.

**Key benefits:**
- Git integration with history, graph visualization, and PR support
- GitHub Copilot for AI-powered code assistance
- Complete Markdown support with preview and linting
- Multi-cursor, code comparison, and local file history
- File format support (YAML, JSON, CSV, XML, Makefile)
- Works out-of-the-box with zero configuration

[📖 Documentation](./features/essential-dev/README.md)

### typescript-dev

TypeScript/JavaScript development setup with indexing, import management, HTML/CSS intelligence, and web tools. Built on top of `essential-dev` for Git, Copilot, and editor enhancements.

**Key benefits:**
- Latest TypeScript with indexing and import management
- HTML and CSS intelligence with auto-rename
- Automatic import/export management and path aliases
- Web development ready with code generation utilities
- Requires `essential-dev` for core tools

[📖 Documentation](./features/typescript-dev/README.md)

### auto-header

Automatically configures file headers with customizable templates based on project, license, company, and contributors information.

**Key benefits:**
- Two header styles: simple (3 lines) and custom (user-defined)
- Flexible configuration with project name, license, company, and contributors
- Helper script `h4-init-headers` for easy initialization
- SPDX compliant license identifiers
- Works in VS Code with zero configuration needed after setup
- Perfect for maintaining consistent file headers across team projects

[📖 Documentation](./features/auto-header/README.md)

## Usage

Features from this repository are available via GitHub Container Registry. Reference them in your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/auto-header:1": {
            "projectName": "my-project"
        },
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {},
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

## Available Features

| Feature | Description | Documentation |
|---------|-------------|---------------|
| [essential-dev](./features/essential-dev) | Core dev environment with Git, Copilot, Markdown, and editor tools | [README](./features/essential-dev/README.md) |
| [vuto-header](./features/auto-header) | Automatic file headers with customizable templates (simple or custom) | [README](./features/auto-header/README.md) |
| [aite-plus](./features/vite-plus) | Complete Vite+ toolchain with Oxc, Vitest, and VS Code integration | [README](./features/vite-plus/README.md) |
| [package-auto-install](./features/package-auto-install) | Automatic package installation with corepack support for Node 24+ | [README](./features/package-auto-install/README.md) |
| [typescript-dev](./features/typescript-dev) | TypeScript/JavaScript dev with indexing and web tools (requires essential-dev) | [README](./features/typescript-dev/README.md) |
| [angular-dev](./features/angular-dev) | Angular development environment with extensions and CLI autocompletion | [README](./features/angular-dev/README.md) |
| [shell-history-per-project](./features/shell-history-per-project) | Per-project shell history persistence with multi-shell auto-detection | [README](./features/shell-history-per-project/README.md) |
| [git-absorb](./features/git-absorb) | Automatic absorption of staged changes into logical commits | [README](./features/git-absorb/README.md) |
| [local-mounts](./features/local-mounts) | Mount local Git, SSH, GPG, and npm config into devcontainer | [README](./features/local-mounts/README.md) |

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

1. Fork the repository
2. Create a feature branch
3. Add your feature following the established patterns
4. Test your feature locally
5. Submit a pull request

## License

This project is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by the [DevContainers Features](https://github.com/devcontainers/features) repository and [stuart leeks' dev-container-features](https://github.com/stuartleeks/dev-container-features) for the shell-history concept, with the key difference being project-scoped rather than global user history persistence.
