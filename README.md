# DevContainer by helpers4

This repository contains a collection of DevContainer Features developed and maintained by helpers4.

Published at: `ghcr.io/helpers4/devcontainer/<feature-name>`

## Features

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

## Usage

Features from this repository are available via GitHub Container Registry. Reference them in your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:0": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:0": {}
    }
}
```

## Available Features

| Feature | Description | Documentation |
|---------|-------------|---------------|
| [shell-history-per-project](./src/shell-history-per-project) | Per-project shell history persistence with multi-shell auto-detection | [README](./src/shell-history-per-project/README.md) |
| [git-absorb](./src/git-absorb) | Automatic absorption of staged changes into logical commits | [README](./src/git-absorb/README.md) |

## Development

This repository follows the [DevContainer Features specification](https://containers.dev/implementors/features/) and is compatible with the [DevContainer Features distribution](https://containers.dev/implementors/features-distribution/).

### Repository Structure

```
.
├── src/
│   └── shell-history-per-project/
│       ├── devcontainer-feature.json
│       ├── install.sh
│       └── README.md
├── test/
│   └── shell-history-per-project/
│       └── test.sh
└── README.md
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
