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
the repos and warns (with a clear message) if that invariant is ever broken.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/pnpm-store:1": {}
  }
}
```

The feature is **zero-config**: it declares its own bind-mount, binding
`${localWorkspaceFolder}/../.pnpm-store` (a sibling of your repos on the host)
onto `/workspaces/.pnpm-store`. That lands on the **same filesystem** as the
bind-mounted repos inside the container, so hardlinks work and the store is
shared across every repo **and** across rebuilds — no manual `mounts` entry
and no options required.

## How it works

1. **At build time** (`install.sh`): writes `store-dir=/workspaces/.pnpm-store`
   into the remote user's `~/.npmrc` so pnpm uses the shared store globally.
2. **At container creation** (`postCreateCommand`): creates and chowns the
   store directory, then compares its filesystem (`stat -c %d`) against each
   repo under `/workspaces`. If any repo is on a different filesystem it warns
   so you can investigate the host-side `.pnpm-store` bind-mount.

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
