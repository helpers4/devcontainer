# Mistral Vibe Development Environment

> Code name: `mistral-dev`

Installs the [Mistral Vibe](https://docs.mistral.ai/vibe/code/overview) IDE extension
across supported editors so every devcontainer gets AI-assisted coding powered
by Mistral out of the box. Credentials and configuration persist in a Docker
named volume linked into the container — they survive all rebuilds, including
`--no-cache`, and GitHub Codespaces.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

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

The volume name includes `${devcontainerId}`, so it's dedicated to this one devcontainer —
credentials and config survive rebuilds of *this* project, but never bleed into another one. The
trade-off: logging in again is needed once per devcontainer, not once per machine. Earlier
versions keyed the volume by `${localEnv:USER}` instead (one identity shared across every local
project) — deliberately dropped, mirroring the same fix applied to [`claude-dev`](../claude-dev):
sharing one AI tool identity across otherwise-unrelated projects risks config/permission
settings from one project silently applying to another, for a convenience (skip re-login) that
isn't worth that trade-off.

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
   `helpers4-mistral-credentials-${devcontainerId}` at `/mnt/h4vibe` inside the container.
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

- **v1.3.0**: **Breaking**: the credentials volume is now keyed by `${devcontainerId}` instead
  of `${localEnv:USER}` — each devcontainer gets its own dedicated volume instead of sharing one
  across every local project. You'll need to log in again once per devcontainer instead of once
  per machine. Mirrors the same fix applied to [`claude-dev`](../claude-dev) — see "GitHub
  Codespaces" above. `h4_ensure_volume_writable` is now called without `--shared`, since an
  exclusive-per-container volume can never have a concurrent writer with a different UID.
- **v1.2.4**: Internal cleanup, no behavior change — dropped dead `_BUILD_ARG_*` fallbacks in
  `install.sh` (`INSTALLCLI`, `USERNAME`). That prefix is only ever set for the legacy
  `internalVersion: "1"` manifest shape, which this feature (and every other one in this
  repo) never declared — the fallback never fired, the plain option env var alone always
  resolved the same value.
- **v1.2.3**: Internal refactor, no behavior change — the shared-volume ownership logic
  (claim on first use, share via `chmod` afterward instead of stealing from another
  project's container) now calls `helpers4-common`'s `h4_ensure_volume_writable --shared`
  instead of carrying its own inline copy.
- **v1.2.2**: Documentation only, no functional change — the previous wording sweep made the
  JSON `description` field far too long, shifting focus away from the feature itself onto the
  self-heal side benefit. Shortened to 5 words and kept generic (no implementation detail like
  "git config"), matching the original's brevity and level of detail.
- **v1.2.1**: Documentation only, no functional change — the self-heal callout above (and the
  JSON `description` field) led with internal jargon ("helpers4's self-heal") instead of the
  actual benefit; reworded to lead with what it does, with the full mechanism staying in
  [`helpers4-common`](../helpers4-common)'s own README.
- **v1.2.0**: Documentation only, no functional change — mentions that `helpers4-common`'s
  automatic git-config self-heal (see above) now comes along with this feature.
- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
- **v1.0.6**: Fixed `EACCES` permission errors on a fresh container: the named volume introduced
  in v1.0.4 is created root-owned by Docker, and nothing chowned it to the container's actual
  user before symlinking `~/.vibe` into it. `setup-credentials.sh` now chowns the volume to the
  current user when needed, same pattern `pnpm-store`'s guard script already used.
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
