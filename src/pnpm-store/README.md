# pnpm Store (pnpm-store)

Shares a single [pnpm](https://pnpm.io) content-addressable store across **every
repo and across rebuilds** via a Docker **named volume**, so no stray
`.pnpm-store` folders pollute your repos.

## Why a named volume?

A named volume is created automatically by Docker, so the feature is fully
**autonomous**: there is no host directory to pre-create, and it works on the
first run everywhere (local bind mounts, Codespaces, clone-in-volume).

pnpm links packages into `node_modules` using **hardlinks**, which require the
store and the code to be on the **same filesystem**. When the workspace lives on
the same filesystem as the volume (e.g. Codespaces / clone-in-volume), pnpm
hardlinks directly. When the repos are bind-mounted from the host — a different
filesystem than the volume — pnpm transparently falls back to copy/copy-on-write.
Either way the store is **shared** and pnpm never recreates a `.pnpm-store`
inside each project.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/pnpm-store:1": {}
  }
}
```

The feature is **zero-config**: it declares its own named-volume mount
(`helpers4-pnpm-store` → `/workspaces/.pnpm-store`) and points pnpm at it. No
manual `mounts` entry and no options required.

## How it works

1. **At build time** (`install.sh`): writes `store-dir=/workspaces/.pnpm-store`
   into the remote user's `~/.npmrc`, and `storeDir: /workspaces/.pnpm-store`
   into `~/.config/pnpm/config.yaml`, so pnpm uses the shared store globally
   regardless of pnpm version (see note below).
2. **At container creation** (`postCreateCommand`): takes ownership of the
   volume (named volumes start root-owned) and re-applies both config files,
   then reports the effective pnpm `store-dir`.

> **pnpm 11 compatibility:** pnpm 11 stopped reading non-auth settings (like
> `store-dir`) from `.npmrc` — they must live in `pnpm-workspace.yaml` or the
> global `~/.config/pnpm/config.yaml`. If only `~/.npmrc` is set and the
> resolved pnpm is v11+, `store-dir` silently resolves to `undefined` and
> pnpm falls back to creating a `.pnpm-store` folder relative to the current
> working directory — exactly the stray folder this feature exists to avoid.
> This feature writes both files so it works across pnpm <11 and >=11.

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

## Version History

- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
