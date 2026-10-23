# Kimi Code Development Environment

> Code name: `kimi-dev`

Installs the [Kimi Code](https://www.kimi.com/code) IDE extension
(`moonshot-ai.kimi-code`) for VS Code and Cursor, and optionally the `kimi`
CLI. Credentials and configuration persist in a Docker named volume linked
into the container — they survive all rebuilds, including `--no-cache`, and
GitHub Codespaces.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/kimi-dev:1": {}
  }
}
```

With the CLI:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/kimi-dev:1": {
      "installCli": true
    }
  }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user that receives the `~/.kimi-code` symlink. `auto` detects vscode/node/codespace/uid-1000, in that order; set an explicit username to override. |
| `installCli` | boolean | `false` | Install the Kimi Code CLI (`kimi` command) via the official native installer. Skipped with a warning if the installer fails. |

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `moonshot-ai.kimi-code` |
| Cursor | ✅ | `moonshot-ai.kimi-code` (same registry as VS Code) |

## Credentials

Kimi Code keeps everything under `~/.kimi-code/`: `config.toml`, OAuth
credentials from `/login`, session state.

`~/.kimi-code` is a symlink to the Docker named volume
`helpers4-kimi-credentials-${devcontainerId}`, mounted at `/mnt/h4kimicode` —
the same model as [`claude-dev`](../claude-dev), [`mistral-dev`](../mistral-dev)
and [`cline-dev`](../cline-dev). The volume is dedicated to this devcontainer:
credentials survive rebuilds of *this* project, but never bleed into another
one, so you sign in once per devcontainer, not once per machine.

No `initializeCommand` required — Docker creates the volume automatically the
first time it's needed.

## How it works

- **Persistence**: `install.sh` links `~/.kimi-code` to `/mnt/h4kimicode` at
  image build time, so the link is valid from the very first process in the
  container — the extension never starts against an empty `~/.kimi-code`. Once
  per container (`postCreateCommand`), `setup-credentials.sh` makes sure the
  volume is writable by the container user, and restores the link if something
  replaced it.
- **Extension**: declared via `customizations.vscode.extensions` in
  `devcontainer-feature.json` — the devcontainer runtime installs it
  automatically, no `install.sh` involvement needed.
- **CLI** (`installCli: true`): `install.sh` runs the official installer
  (`https://code.kimi.com/kimi-code/install.sh`) at build time with
  `KIMI_INSTALL_DIR=/usr/local`, so the binary lands directly at
  `/usr/local/bin/kimi` — on PATH for every user, and outside the persisted
  `~/.kimi-code` volume (the installer's default install dir *is*
  `~/.kimi-code`, which would collide with the volume symlink). No Node.js
  required. If the installer fails (network, unsupported platform), the build
  continues with a warning rather than failing.

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images; the CLI's native installer does
  not support Alpine/musl — use `npm install -g @moonshot-ai/kimi-code` there
  instead)
- **Architectures:** amd64, arm64

## Version History

- **v1.0.0**: Initial release.
