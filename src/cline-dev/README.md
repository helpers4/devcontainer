# Cline Development Environment

> Code name: `cline-dev`

Installs the [Cline](https://cline.bot) AI coding agent extension for VS Code
and Cursor, and optionally the `cline` CLI. Provider keys, settings and task
history persist in a Docker named volume linked into the container — they survive
all rebuilds, including `--no-cache`, and GitHub Codespaces.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

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
| `username` | string | `auto` | Container user that receives the `~/.cline` symlink. `auto` detects vscode/node/codespace/uid-1000, in that order; set an explicit username to override. |
| `installCli` | boolean | `false` | Install the Cline CLI (`cline` command) via npm. Requires Node.js/npm; skipped with a warning if not found. |

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `saoudrizwan.claude-dev` |
| Cursor | ✅ | `saoudrizwan.claude-dev` (same registry as VS Code) |

## Credentials

Cline (extension 4.x and CLI alike) keeps everything under `~/.cline/data/`:
provider API keys in `settings/providers.json`, global state, task history. VS
Code's `SecretStorage` is only read once, to migrate keys from older versions.

`~/.cline` is a symlink to the Docker named volume
`helpers4-cline-credentials-${devcontainerId}`, mounted at `/mnt/h4cline` — the
same model as [`claude-dev`](../claude-dev) and [`mistral-dev`](../mistral-dev).
The volume is dedicated to this devcontainer: keys survive rebuilds of *this*
project, but never bleed into another one, so you sign in once per devcontainer,
not once per machine. The extension and the CLI share it, so `cline auth` in the
terminal and the extension see the same keys.

No `initializeCommand` required — Docker creates the volume automatically the
first time it's needed.

## How it works

- **Persistence**: `install.sh` links `~/.cline` to `/mnt/h4cline` at image build
  time, so the link is valid from the very first process in the container — the
  extension never starts against an empty `~/.cline`. Once per container
  (`postCreateCommand`), `setup-credentials.sh` makes sure the volume is writable
  by the container user, and restores the link if something replaced it.
- **Extension**: declared via `customizations.vscode.extensions` in
  `devcontainer-feature.json` — the devcontainer runtime installs it
  automatically, no `install.sh` involvement needed.
- **CLI** (`installCli: true`): `install.sh` runs `npm install -g cline` at
  build time. If `npm` isn't present, the install is skipped with a warning
  rather than failing the build — add a Node.js feature (e.g.
  `ghcr.io/devcontainers/features/node`) before `cline-dev` if you want the
  CLI.

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.1.0**: Provider keys, settings and task history now survive rebuilds: `~/.cline` is
  linked to a Docker named volume dedicated to this devcontainer. Earlier versions persisted
  nothing, and this README wrongly said Cline kept its keys in VS Code's `SecretStorage` — Cline
  4.x stores them in `~/.cline/data/settings/providers.json`. New `username` option; now
  depends on `helpers4-common`. You'll need to sign in once more after upgrading.
- **v1.0.1**: Internal cleanup, no behavior change — dropped a dead `_BUILD_ARG_INSTALLCLI`
  fallback in `install.sh`. That prefix is only ever set for the legacy
  `internalVersion: "1"` manifest shape, which this feature (and every other one in this
  repo) never declared — the fallback never fired, `${INSTALLCLI:-false}` alone always
  resolved the same value.
- **v1.0.0**: Initial release.
