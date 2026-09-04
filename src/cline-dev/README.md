# Cline Development Environment (cline-dev)

Installs the [Cline](https://cline.bot) AI coding agent extension for VS Code
and Cursor, and optionally the `cline` CLI.

> **Naming note:** Cline's VS Code marketplace ID is still `saoudrizwan.claude-dev`
> — a holdover from before the project renamed itself from "Claude Dev" to Cline.
> It has nothing to do with this repo's own [`claude-dev`](../claude-dev) feature,
> which installs Anthropic's official Claude Code extension.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/cline-dev:1": {}
  }
}
```

With the CLI:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/cline-dev:1": {
      "installCli": true
    }
  }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installCli` | boolean | `false` | Install the Cline CLI (`cline` command) via npm. Requires Node.js/npm; skipped with a warning if not found. |

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `saoudrizwan.claude-dev` |
| Cursor | ✅ | `saoudrizwan.claude-dev` (same registry as VS Code) |

## Credentials

Unlike `claude-dev`/`mistral-dev`, this feature persists nothing across
rebuilds. Cline stores its API key via VS Code's own `SecretStorage` API
(encrypted, under `~/.config/Code/User/globalStorage/saoudrizwan.claude-dev/`)
rather than a plain dotfile — there's no single directory to bind-mount or
volume-mount the way `~/.claude`/`~/.vibe` work for the other two. Re-enter
your API key (or run `cline auth` for the CLI) after a rebuild.

## How it works

- **Extension**: declared via `customizations.vscode.extensions` in
  `devcontainer-feature.json` — the devcontainer runtime installs it
  automatically, no `install.sh` involvement needed.
- **CLI** (`installCli: true`): `install.sh` runs `npm install -g cline` at
  build time. If `npm` isn't present, the install is skipped with a warning
  rather than failing the build — add a Node.js feature (e.g.
  `ghcr.io/devcontainers/features/node`) before `cline-dev` if you want the
  CLI.

## OS and Architecture Support

- **OS:** any (no OS-level installation — pure IDE configuration)
- **Architectures:** amd64, arm64
