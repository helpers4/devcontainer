# Mistral Vibe Development Environment (mistral-dev)

Installs the [Mistral Vibe](https://docs.mistral.ai/vibe/code/overview) IDE extension
across supported editors so every devcontainer gets AI-assisted coding powered
by Mistral out of the box. Credentials and configuration stored in `~/.vibe/`
on the host are linked into the container — they persist across all rebuilds,
including `--no-cache`.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/mistral-dev:1": {}
  }
}
```

Add `initializeCommand` to your `devcontainer.json` so the host directory is
guaranteed to exist before Docker tries to bind-mount it:

```jsonc
{
  "initializeCommand": "mkdir -p ~/.vibe",
  "features": {
    "ghcr.io/helpers4/devcontainer/mistral-dev:1": {}
  }
}
```

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
2. **Mount** (`devcontainer-feature.json → mounts`): bind-mounts `$HOME/.vibe` from
   the host to `/mnt/h4vibe` inside the container.
3. **Every start** (`postStartCommand`): `setup-credentials.sh` replaces `~/.vibe`
   with a symlink to `/mnt/h4vibe` — credentials and config survive rebuilds.

This means:
- Credentials survive container rebuilds (including `--no-cache`).
- First-time auth inside the container writes back to the host automatically.
- `VIBE_HOME` is not required — the symlink is transparent to Mistral Vibe.

Docker refuses to start the container if a bind-mount source has never existed
on the host (fresh machine, first Vibe login). A Feature's `devcontainer-feature.json`
can't fix this itself — `initializeCommand` set there is silently ignored by the
devcontainers CLI, only the consumer's top-level `devcontainer.json` is honored for
it — which is why `initializeCommand` above is required in your own config rather
than bundled into the feature. If `/mnt/h4vibe` is not mounted (e.g. missing
`initializeCommand`, standalone test), the script errors out — check that
`initializeCommand` is present in your `devcontainer.json`.

### CLI (optional)
When `installCli: true`, the `vibe` command is installed at build time via `uv`
(preferred) or `pip`. See [Mistral Vibe CLI docs](https://docs.mistral.ai/vibe/code/cli/install-setup).

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64
