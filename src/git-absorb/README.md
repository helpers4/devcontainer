# git-absorb

This DevContainer feature installs [git-absorb](https://github.com/tummychow/git-absorb), a tool that automatically absorbs staged changes into their logical commits. It's like `git commit --fixup` but automatic.

## Features

- **Automatic fixup commits**: Absorbs staged changes into existing commits automatically
- **Multi-architecture support**: Works on x86_64 and aarch64 Linux systems
- **Latest version**: Always installs the most recent release by default
- **Git integration**: Available as `git absorb` subcommand
- **Lightweight**: Single binary installation with minimal dependencies

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/git-absorb:0": {}
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `latest` | Version of git-absorb to install (e.g., "0.6.11" or "latest") |

## Examples

### Basic usage (latest version)

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/git-absorb:0": {}
    }
}
```

### Specific version

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/git-absorb:0": {
            "version": "0.6.11"
        }
    }
}
```

## How git-absorb works

git-absorb automatically identifies which commits your staged changes belong to and creates fixup commits for them.

### Workflow example:

1. **Make some commits**:
   ```bash
   git commit -m "Add feature A"
   git commit -m "Add feature B"
   git commit -m "Add feature C"
   ```

2. **Make changes to files** (fix bugs, improve code, etc.)

3. **Stage your changes**:
   ```bash
   git add .
   ```

4. **Let git-absorb work its magic**:
   ```bash
   git absorb
   ```

git-absorb will automatically create fixup commits that can be squashed into the appropriate original commits using `git rebase --autosquash`.

### Preview changes first:

```bash
git absorb --dry-run
```

This shows what git-absorb would do without actually creating commits.

## Commands

Once installed, you can use git-absorb in several ways:

### As a Git subcommand:
```bash
git absorb                    # Absorb staged changes
git absorb --dry-run         # Preview what would be absorbed
git absorb --help           # Show help
```

### As a standalone command:
```bash
git-absorb                   # Absorb staged changes
git-absorb --dry-run        # Preview what would be absorbed
git-absorb --version        # Show version
```

## Use cases

- **Bug fixes**: Fix a bug and let git-absorb put the fix in the right commit
- **Code improvements**: Refactor code and automatically organize changes
- **Documentation**: Add comments or docs and absorb them into relevant commits
- **Style fixes**: Fix formatting and absorb into the commits that introduced the code

## Tips

1. **Use --dry-run first** to see what git-absorb plans to do
2. **Stage only what you want to absorb** - git-absorb only works with staged changes
3. **Works best with recent commits** - git-absorb looks at recent history to find matching commits
4. **Combine with git rebase --autosquash** to clean up your branch before merging

## Requirements

- Git must be installed and configured
- Linux x86_64 or aarch64 architecture
- Recent commits in your repository (git-absorb needs context to work with)

## Architecture support

- ✅ Linux x86_64 (amd64)
- ✅ Linux aarch64 (ARM64)
- ❌ Other architectures (not supported by upstream git-absorb releases)

## Troubleshooting

- **"No commits available to fix up"**: You need existing commits for git-absorb to work with
- **Changes not absorbed**: Make sure your changes are staged (`git add`)
- **Binary not found**: Check that `/usr/local/bin` is in your PATH

## About git-absorb

git-absorb is created by [tummychow](https://github.com/tummychow) and is inspired by Facebook's `hg absorb` command for Mercurial. It uses advanced heuristics to determine which commits your changes should be absorbed into.

For more information, visit the [official git-absorb repository](https://github.com/tummychow/git-absorb).

## Contributing

This feature is part of the `helpers4/devcontainer-features` repository. Contributions and issues are welcome!