# pnpm Store (pnpm-store)

Configures a shared [pnpm](https://pnpm.io) content-addressable store on the
**same filesystem as your code**, so pnpm's hardlinks work and no stray
`.pnpm-store` folders pollute your repos.

## Why not a Docker volume?

pnpm links packages into `node_modules` using **hardlinks**, which cannot cross
a filesystem boundary. In a typical devcontainer the repos are **bind-mounted**
from the host, while a Docker named volume lives in `/var/lib/docker` — a
**different filesystem**. When the store and the code are on different
filesystems, pnpm silently abandons the shared store and recreates a
`.pnpm-store` **inside each project**.

This feature instead points the store at a path on the **same filesystem** as
the repos and fails fast (with a clear message) if that invariant is broken.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/pnpm-store:1": {}
  },
  // Required: bind-mount a host folder, sibling of your repos, onto the store.
  "mounts": [
    "source=${localWorkspaceFolder}/../.pnpm-store,target=/workspaces/.pnpm-store,type=bind,consistency=cached"
  ]
}
```

The bind-mount source is a sibling of your repos on the host, so it lands on the
**same filesystem** as the bind-mounted repos inside the container — hardlinks
work, and the store is shared across every repo **and** across rebuilds.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `storeDir` | string | `/workspaces/.pnpm-store` | Absolute path of the pnpm store. Must live on the same filesystem as your repos. |
| `setGlobalConfig` | boolean | `true` | Write `store-dir=<storeDir>` into the remote user's `~/.npmrc`. |
| `failIfCrossDevice` | boolean | `true` | Fail container creation if the store is on a different filesystem than a repo. |
| `checkAgainst` | string | `/workspaces` | Directory whose immediate subdirectories are checked against the store's filesystem. |

## How it works

1. **At build time** (`install.sh`): writes `store-dir=<storeDir>` into the
   remote user's `~/.npmrc` so pnpm uses the shared store globally.
2. **At container creation** (`postCreateCommand`): creates and chowns the
   store directory, then compares its filesystem (`stat -c %d`) against each
   subdirectory of `checkAgainst`. If any repo is on a different filesystem it
   prints the exact bind-mount fix and, when `failIfCrossDevice` is `true`,
   aborts before pnpm has a chance to pollute the repos.

## Ensuring pnpm is installed

This feature does not install pnpm. It expects pnpm to be provided by the base
image or another feature. The store configuration is written regardless; the
guard simply reports the effective `store-dir` when pnpm is on the `PATH`.

If another feature installs pnpm, you may need
[`overrideFeatureInstallOrder`](https://containers.dev/implementors/features/#overrideFeatureInstallOrder)
to ensure it runs before `pnpm-store`.

## OS and Architecture Support

- **OS:** Debian, Ubuntu (any base image)
- **Architectures:** amd64, arm64
- **Shells:** bash, zsh, fish (configuration via `~/.npmrc`)
