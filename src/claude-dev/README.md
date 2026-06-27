# Claude Code Development Environment (claude-dev)

Installs the [Claude Code](https://www.anthropic.com/claude-code) IDE extension
across supported editors and persists `~/.claude` (credentials, config, memory)
across every devcontainer rebuild via a host bind-mount.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {}
  }
}
```

Add `initializeCommand` to your `devcontainer.json` so the host directory is
guaranteed to exist before Docker tries to bind-mount it:

```jsonc
{
  "initializeCommand": "mkdir -p ~/.claude",
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {}
  }
}
```

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `anthropic.claude-code` |
| Cursor | ✅ | `anthropic.claude-code` (same registry as VS Code) |
| JetBrains (IntelliJ, WebStorm…) | 🔜 | pending `xmlId` confirmation — marketplace page: [plugin/27310](https://plugins.jetbrains.com/plugin/27310) (vendor: Anthropic) |
| Zed | 🔜 | no standard devcontainer customization format yet |

## How it works

1. **Build time** (`install.sh`): generates `/usr/local/share/claude-dev/setup-credentials.sh`
   with the target user's home path baked in.
2. **Mount** (`devcontainer-feature.json → mounts`): bind-mounts `$HOME/.claude` from
   the host to `/mnt/h4claude` inside the container.
3. **Every start** (`postStartCommand`): `setup-credentials.sh` replaces `~/.claude`
   with a symlink to `/mnt/h4claude` — credentials, settings, and Claude Code memory
   all survive rebuilds.

If `/mnt/h4claude` is not mounted (e.g. missing `initializeCommand`, standalone test),
the script warns and exits cleanly — the container starts normally, just without persistence.

## OS and Architecture Support

- **OS:** any (no OS-level installation — pure IDE configuration)
- **Architectures:** amd64, arm64
