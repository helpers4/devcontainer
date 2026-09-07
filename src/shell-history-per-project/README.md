# Shell History Per Project

This DevContainer feature provides shell history persistence per project by mounting a shell directory and creating symbolic links internally. This ensures that your shell history is preserved across container rebuilds and is isolated per project.

> **Also included automatically:** helpers4's self-heal mechanism, working on both local and
> cloud containers. It does its best to fix broken paths and a missing commit-signing key, with
> nothing to set up on your end. It comes from this feature's dependency on `helpers4-common` —
> you never need to add that feature yourself.

## Features

- **Per-project history isolation**: Each project maintains its own shell history
- **Multiple shell support**: Supports zsh, bash, and fish shells
- **Persistent across rebuilds**: History is preserved when containers are rebuilt
- **Configurable**: Customizable history directory and size limits
- **Symbolic link approach**: Uses internal symbolic links for seamless integration

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {}
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `shell` | string | `zsh` | Shell type to configure (`zsh`, `bash`, or `fish`) |
| `historyDirectory` | string | `/workspaces/.shell-history` | Directory where shell history will be persisted |
| `maxHistorySize` | string | `10000` | Maximum number of history entries to keep |

## Examples

### Basic usage with default zsh

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {}
    }
}
```

### Custom configuration

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {
            "shell": "bash",
            "historyDirectory": "/workspaces/.custom-history",
            "maxHistorySize": "50000"
        }
    }
}
```

### With volume mount

For persistent history across different development sessions, you might want to add a volume mount:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {
            "historyDirectory": "/workspaces/.shell-history"
        }
    },
    "mounts": [
        "source=${localWorkspaceFolder}/.devcontainer/shell-history,target=/workspaces/.shell-history,type=bind"
    ]
}
```

## How it works

1. **Creates a persistent history directory**: The feature creates a dedicated directory for storing shell history files
2. **Configures shell settings**: Updates the shell configuration files to use the persistent history location
3. **Creates symbolic links**: Links the default history file location to the persistent location
4. **Sets appropriate permissions**: Ensures proper file permissions for the remote user

## Supported shells

- **Zsh**: Configures `.zsh_history` with optimal history settings including `SHARE_HISTORY`, `HIST_IGNORE_DUPS`, etc.
- **Bash**: Configures `.bash_history` with `histappend` and duplicate handling
- **Fish**: Configures `fish_history` with appropriate Fish shell settings

## Directory structure

After installation, you'll have:

```
/workspaces/.shell-history/
├── .zsh_history          # (for zsh)
├── .bash_history         # (for bash)
└── fish_history          # (for fish)
```

With symbolic links from the standard locations:
- `~/.zsh_history` → `/workspaces/.shell-history/.zsh_history`
- `~/.bash_history` → `/workspaces/.shell-history/.bash_history`
- `~/.local/share/fish/fish_history` → `/workspaces/.shell-history/fish_history`

## Benefits over global history mounting

Unlike mounting the user's global shell history, this approach provides:

1. **Project isolation**: Each project maintains its own command history
2. **Team collaboration**: History can be shared among team members if desired
3. **Context relevance**: Commands are relevant to the specific project
4. **Clean development**: No mixing of personal and project commands
5. **Flexibility**: Easy to configure different settings per project

## Comparison with stuartleeks/dev-container-features shell-history

This feature differs from the existing shell-history feature by:

- **Project-scoped**: History is isolated per project instead of global user history
- **Internal symbolic links**: Uses symbolic links internally rather than mounting user's home directory
- **Collaborative**: Can be shared with team members through project setup
- **Configurable location**: Allows customization of where history is stored within the project

## Contributing

This feature is part of the `helpers4/devcontainer-features` repository. Contributions and issues are welcome!

## Version History

- **v1.2.0**: Documentation only, no functional change — mentions that `helpers4-common`'s
  automatic git-config self-heal (see above) now comes along with this feature.
- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
