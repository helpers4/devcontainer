# Mistral Vibe Development Environment (mistral-dev)

Installs the [Mistral Vibe](https://docs.mistral.ai/vibe/code/overview) IDE extension
across supported editors so every devcontainer gets AI-assisted coding powered
by Mistral out of the box. Credentials and configuration persist in a Docker
named volume linked into the container — they survive all rebuilds, including
`--no-cache`, and GitHub Codespaces.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/mistral-dev:1": {}
  }
}
```

No `initializeCommand` required — Docker creates the volume automatically the
first time it's needed.

With the optional CLI:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/mistral-dev:1": {
      "installCli": true
    }
  }
}
```

## GitHub Codespaces

Works out of the box. A host bind-mount would not: [GitHub Codespaces doesn't
support mounting the local file system](https://code.visualstudio.com/remote/advancedcontainers/add-local-file-mount)
at all, so this feature uses a Docker named volume instead. Each codespace
gets its own volume, populated on your first Vibe login there.

The volume name includes `${localEnv:USER}`, so credentials are shared across
every local devcontainer for the same OS user — matching what a bind-mount to
`~/.vibe` would give you — while staying isolated from other OS users on a
shared Docker host. On a host where `$USER` isn't set, anyone missing it
shares one volume; not a concern on a personal machine or a codespace, worth
knowing on a shared multi-user build server.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user that receives the `~/.vibe` symlink. `auto` detects vscode/node/codespace/uid-1000, in that order; set an explicit username to override. |
| `installCli` | boolean | `false` | Install the `vibe` CLI. Requires Python 3.12+ or `uv` in the container. |

## IDE support

| Editor | Status | ID |
|--------|--------|----|
| VS Code | ✅ | `mistralai.mistral-vibe-code` |
| Cursor | ✅ | `mistralai.mistral-vibe-code` (same registry as VS Code) |

## How it works

### Extension
The feature declares the `mistralai.mistral-vibe-code` extension via the
`customizations` field in `devcontainer-feature.json`. The devcontainer runtime
installs it automatically.

### Credential persistence
1. **Build time** (`install.sh`): generates `/usr/local/share/mistral-dev/setup-credentials.sh`
   with the target user's home path baked in.
2. **Mount** (`devcontainer-feature.json → mounts`): mounts the Docker named volume
   `helpers4-mistral-credentials-${localEnv:USER}` at `/mnt/h4vibe` inside the container.
3. **Every start** (`postStartCommand`): `setup-credentials.sh` replaces `~/.vibe`
   with a symlink to `/mnt/h4vibe` — credentials and config survive rebuilds.

This means:
- Credentials survive container rebuilds (including `--no-cache`) and Codespaces.
- First-time auth inside the container writes back to the volume automatically.
- `VIBE_HOME` is not required — the symlink is transparent to Mistral Vibe.

If `/mnt/h4vibe` is not mounted (e.g. a standalone `install.sh` test), the
script warns and exits cleanly — the container starts normally, just without
persistence.

### CLI (optional)
When `installCli: true`, the `vibe` command is installed at build time via `uv`
(preferred) or `pip`. See [Mistral Vibe CLI docs](https://docs.mistral.ai/vibe/code/cli/install-setup).

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.0.5**: A missing `/mnt/h4vibe` mount now warns and exits cleanly instead of erroring out
  — the container starts normally, just without persistence, matching `claude-dev`'s behavior
  for the structurally identical situation.
- **v1.0.4**: Switched credential persistence from a host bind-mount to a Docker named volume
  to fix GitHub Codespaces, which doesn't support host bind-mounts at all (#66). **If you're
  upgrading from v1.0.3 or earlier**, this is a breaking change: the new volume starts empty —
  your old host-bound `~/.vibe` isn't copied in automatically. Re-authenticate once after
  upgrading, or manually copy your old `~/.vibe` content into the new volume (e.g. `docker cp`
  into a throwaway container mounting `helpers4-mistral-credentials-${USER}`) if you want to
  keep it.
