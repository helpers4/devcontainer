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

## Version History

- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
- **v1.0.8**: Fixed `EACCES` errors (e.g. "Failed to retrieve auth status after login",
  `mkdir '.../sessions'` permission denied) on a fresh container: the named volume introduced in
  v1.0.6 is created root-owned by Docker, and nothing chowned it to the container's actual user
  before symlinking `~/.claude` into it. `setup-credentials.sh` now chowns the volume to the
  current user when needed, same pattern `pnpm-store`'s guard script already used.
- **v1.0.7**: Added `installCli` to install the `claude` CLI alongside the extension.
- **v1.0.6**: Switched credential persistence from a host bind-mount to a Docker named volume
  to fix GitHub Codespaces, which doesn't support host bind-mounts at all (#66). **If you're
  upgrading from v1.0.5 or earlier**, this is a breaking change: the new volume starts empty —
  your old host-bound `~/.claude` isn't copied in automatically. Re-authenticate once after
  upgrading, or manually copy your old `~/.claude` content into the new volume (e.g. `docker cp`
  into a throwaway container mounting `helpers4-claude-credentials-${USER}`) if you want to
  keep it.
