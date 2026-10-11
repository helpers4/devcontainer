# Shell History

> Code name: `shell-history`

Keeps your bash, zsh and fish history across container rebuilds, `--no-cache` included, and
GitHub Codespaces. The history lives in a Docker named volume dedicated to this devcontainer:
each project keeps its own commands, and never sees another project's.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

> **Formerly `shell-history-per-project`.** That feature kept history under
> `/workspaces/.shell-history`, which only survived a rebuild where `/workspaces` itself was
> persisted (GitHub Codespaces) — with VS Code's default mount, it was lost every time. See
> [the migration notes](https://github.com/helpers4/devcontainer/tree/main/deprecated/shell-history-per-project).

## When to use this

Use this when you want the commands you typed in a devcontainer to still be there after a
rebuild, without one project's history showing up in another's.

**Alternatives:**
- Bind-mounting your host's own history file (`~/.zsh_history`) shares one history across every
  project and the host itself, and fails the container build wherever that file doesn't exist
  (Codespaces, a fresh machine).
- [stuartleeks/dev-container-features](https://github.com/stuartleeks/dev-container-features)
  also has a `shell-history` feature built on a named volume.

## Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/shell-history:1": {}
  }
}
```

No `initializeCommand` required — Docker creates the volume automatically the first time it's
needed.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user whose shells keep their history. `auto` detects vscode/node/codespace/uid-1000, in that order. |
| `maxHistorySize` | string | `10000` | Number of history entries to keep, in memory and in the history file (bash and zsh). |

## How it works

Every shell found in the image (bash, zsh, fish) is configured; there's nothing to pick.

1. **Build time** (`install.sh`): points each shell's history at `/mnt/h4history`, owned by the
   container user and private (`700` / `600` — history often holds a token typed on a command
   line).
   - **bash** — a block at the end of `~/.bashrc`: `HISTFILE`, `HISTSIZE` and `HISTFILESIZE`
     (overriding the distro's own defaults, e.g. Debian's 1000 / 2000), `histappend`, and
     `history -a` in `PROMPT_COMMAND` so each command is saved as soon as it runs — not only
     when the shell exits cleanly, which a container stop or a closed terminal never does.
   - **zsh** — a block at the end of `~/.zshrc`: `HISTFILE`, `HISTSIZE`, `SAVEHIST`,
     `SHARE_HISTORY` (each command saved as it runs, and shared between open terminals).
   - **fish** — `~/.local/share/fish` is linked to the volume. fish has no setting for its
     history path, and saves through a temporary file it then renames, so linking the file
     alone would not survive the first save.
   - `~/.bash_history` and `~/.zsh_history` link to the volume too, for tools that read them
     directly.

   The blocks sit between `# >>> helpers4 shell-history >>>` markers: installing again replaces
   them instead of stacking copies.
2. **Mount** (`devcontainer-feature.json → mounts`): the Docker named volume
   `helpers4-shell-history-${devcontainerId}` is attached at `/mnt/h4history` before any shell
   starts.
3. **Once per container** (`postCreateCommand`): `setup-volume.sh` makes sure the volume is
   writable by the container user, and imports the history `shell-history-per-project` left in
   `/workspaces/.shell-history`, if any.

```text
/mnt/h4history/          (volume, 700)
├── bash_history         (600)
├── zsh_history          (600)
└── fish/fish_history
```

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.0.0**: Renamed from `shell-history-per-project` (last release v1.2.3), and history now
  actually survives rebuilds: a named volume dedicated to this devcontainer replaces
  `/workspaces/.shell-history`. Also fixed along the way: `maxHistorySize` now applies to bash's
  history file too (Debian's `HISTFILESIZE=2000` used to win), bash saves each command as it
  runs, fish history is really persisted, history files are private instead of world-readable,
  and installing again no longer stacks duplicate blocks in `~/.bashrc` / `~/.zshrc`. The
  `targetShell` and `historyDirectory` options are gone: every installed shell is configured,
  and the history lives in the volume.
