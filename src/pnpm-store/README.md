# pnpm Store (shared)

> Code name: `pnpm-store`

Shares a single [pnpm](https://pnpm.io) content-addressable store across **every
repo and across rebuilds** via a Docker **named volume**, so no stray
`.pnpm-store` folders pollute your repos.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

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
(`helpers4-pnpm-store-${localEnv:USER}` → `/workspaces/.pnpm-store`) and points pnpm at it. No
manual `mounts` entry and no options required. The volume name includes `${localEnv:USER}`, so
it's shared across every local devcontainer for the same host OS user — not just every repo
inside one devcontainer — matching how pnpm's own store already works on a bare-metal machine.
Content-addressed package bytes carry no registry credentials (those stay in `~/.npmrc`, handled
separately by `dotfiles-sync`), so unlike an AI tool's credentials volume, there's no
identity/permissions surface to leak between otherwise-unrelated projects.

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

## Compatibility with nub

[`nub`](../nub) has its own embedded install engine rather than shelling out to `pnpm`, but it
reads the same `store-dir`/`storeDir` config this feature writes and hardlinks package content
from it — verified directly, including an offline reinstall with `nub`'s own cache cleared. The
two features are safe to combine; see `nub`'s README for details.

## OS and Architecture Support

- **OS:** Debian, Ubuntu (any base image)
- **Architectures:** amd64, arm64
- **Shells:** bash, zsh, fish (configuration via `~/.npmrc`)

## Version History

- **v1.3.1**: Documentation only, no functional change — centralized the exclusive-vs-shared
  volume rationale onto `h4_ensure_volume_writable`'s own comment in `helpers4-common`, trimming
  the near-identical explanation this file (and claude-dev/mistral-dev/playwright-dev) used to
  restate independently.
- **v1.3.0**: The store volume is now keyed by `${localEnv:USER}` instead of
  `${devcontainerId}` — shared across every local devcontainer for this host OS user, not just
  every repo inside one devcontainer, matching pnpm's own bare-metal default of one global
  store. Safe unlike an AI tool's credentials volume: the store holds only hash-addressed
  package bytes, never registry tokens. `h4_ensure_volume_writable` is now called with
  `--shared`, since a second, concurrently-running devcontainer can resolve a different
  container UID.
- **v1.2.4**: Documentation only, no functional change — added a "Compatibility with nub" section
  documenting a verified finding: `nub install` hardlinks package content from this feature's
  shared store instead of duplicating it.
- **v1.2.3**: Internal refactor, no behavior change — the store-directory ownership logic
  (chown to the current user when needed) now calls `helpers4-common`'s
  `h4_ensure_volume_writable` instead of carrying its own inline copy.
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
