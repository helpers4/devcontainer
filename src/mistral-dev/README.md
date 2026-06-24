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
| `username` | string | `node` | Container user that receives the `~/.vibe` symlink. |
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
At build time, `install.sh` generates `/usr/local/share/mistral-dev/setup-credentials.sh`
with the target user's home directory baked in. At every container start
(`postStartCommand`), that script replaces `~/.vibe` with a symlink pointing to
the host bind-mounted path `/mnt/h4vibe` (sourced from `~/.vibe` on the host).

This means:
- Credentials survive container rebuilds (including `--no-cache`).
- First-time auth inside the container writes back to the host automatically.
- `VIBE_HOME` is not required — the symlink is transparent to Mistral Vibe.

### CLI (optional)
When `installCli: true`, the `vibe` command is installed at build time via `uv`
(preferred) or `pip`. See [Mistral Vibe CLI docs](https://docs.mistral.ai/vibe/code/cli/install-setup).

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64
