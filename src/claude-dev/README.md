# Claude Code Development Environment (claude-dev)

Installs the [Claude Code](https://www.anthropic.com/claude-code) IDE extension
across supported editors and persists `~/.claude` (credentials, config, memory)
across every devcontainer rebuild — including GitHub Codespaces — via a Docker
named volume. Optionally installs the `claude` CLI too.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {}
  }
}
```

No `initializeCommand` required — Docker creates the volume automatically the
first time it's needed.

With the CLI:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {
      "installCli": true
    }
  }
}
```

## GitHub Codespaces

Works out of the box. A host bind-mount would not: [GitHub Codespaces doesn't
support mounting the local file system](https://code.visualstudio.com/remote/advancedcontainers/add-local-file-mount)
at all, so this feature uses a Docker named volume instead. Each codespace
gets its own volume, populated on your first `/login` there.

The volume name includes `${localEnv:USER}`, so credentials are shared across
every local devcontainer for the same OS user — matching what a bind-mount to
`~/.claude` would give you — while staying isolated from other OS users on a
shared Docker host. On a host where `$USER` isn't set, anyone missing it
shares one volume; not a concern on a personal machine or a codespace, worth
knowing on a shared multi-user build server.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user that receives the `~/.claude` symlink. `auto` detects vscode/node/codespace/uid-1000, in that order; set an explicit username to override. |
| `installCli` | boolean | `false` | Install the Claude Code CLI (`claude` command) via the official native installer. |

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
2. **Mount** (`devcontainer-feature.json → mounts`): mounts the Docker named volume
   `helpers4-claude-credentials-${localEnv:USER}` at `/mnt/h4claude` inside the container.
3. **Every start** (`postStartCommand`): `setup-credentials.sh` replaces `~/.claude`
   with a symlink to `/mnt/h4claude` — credentials, settings, and Claude Code memory
   all survive rebuilds.

If `/mnt/h4claude` is not mounted (e.g. a standalone `install.sh` test), the
script warns and exits cleanly — the container starts normally, just without
persistence.

With `installCli: true`, `install.sh` also runs the official native installer
(`curl -fsSL https://claude.ai/install.sh | bash`) as the target user, then
symlinks the resulting binary into `/usr/local/bin/claude` so it's on `PATH`
without depending on that user's shell profile already including
`~/.local/bin`.

## OS and Architecture Support

- **OS:** any (no OS-level installation — pure IDE configuration)
- **Architectures:** amd64, arm64
