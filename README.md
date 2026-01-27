# DevContainer Features by helpers4

This repository contains a collection of DevContainer Features developed and maintained by helpers4.

Published at: `ghcr.io/helpers4/devcontainer/<feature-name>`

## Features

### package-auto-install

Automatically detects and runs npm/yarn/pnpm install in non-interactive mode after container creation. Handles corepack setup for Node 24+ and intelligently detects the package manager from package.json or lockfiles.

**Key benefits:**
- Automatic package manager detection from package.json or lockfiles
- Corepack support for Node 24+ (auto-installs if needed)
- Non-interactive mode (CI=true) prevents prompts
- Smart command selection (npm ci, pnpm --frozen-lockfile, yarn --immutable)
- Eliminates need for manual postCreateCommand

[📖 Documentation](./src/package-auto-install/README.md)

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

### local-mounts

Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication. Now with proper SSH agent forwarding support.

**Key benefits:**
- Git configuration available inside container
- SSH keys and SSH agent forwarding configured automatically
- GPG keys for commit signing
- npm authentication for private registries
- Fixed SSH_AUTH_SOCK handling for devcontainer compatibility

[📖 Documentation](./src/local-mounts/README.md)

## Usage

Features from this repository are available via GitHub Container Registry. Reference them in your `devcontainer.json`:

```json
{
    "features": {package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/
        "ghcr.io/helpers4/devcontainer/angular-dev:1": {},
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

## Available Features

| Feature | Description | Documentation |
|--package-auto-install](./src/package-auto-install) | Automatic package installation with corepack support for Node 24+ | [README](./src/package-auto-install/README.md) |
| [-------|-------------|---------------|
| [angular-dev](./src/angular-dev) | Angular development environment with extensions and CLI autocompletion | [README](./src/angular-dev/README.md) |
| [shell-history-per-project](./src/shell-history-per-project) | Per-project shell history persistence with multi-shell auto-detection | [README](./src/shell-history-per-project/README.md) |
| [git-absorb](./src/git-absorb) | Automatic absorption of staged changes into logical commits | [README](./src/git-absorb/README.md) |
| [local-mounts](./src/local-mounts) | Mount local Git, SSH, GPG, and npm config into devcontainer | [README](./src/local-mounts/README.md) |

## Development

This repository follows the [DevContainer Features specification](https://containers.dev/implementors/features/) and is compatible with the [DevContainer Features distribution](https://containers.dev/implementors/features-distribution/).

### Repository Structure

```
.package-auto-install/
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── angular-dev/
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── git-absorb/
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   ├── local-mounts/
│   │   ├── devcontainer-feature.json
│   │   ├── install.sh
│   │   └── README.md
│   └── shell-history-per-project/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/
│   ├── package-auto-install/
│   │   └── test.sh── install.sh
│       └── README.md
├── test/
│   ├── angular-dev/
│   │   └── test.sh
│   ├── git-absorb/
│   │   └── test.sh
│   ├── local-mounts/
│   │   └── test.sh
│   └── shell-history-per-project/
│       └── test.sh
└── README.mdpackage-auto-install
devcontainer features test --features 
```

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
