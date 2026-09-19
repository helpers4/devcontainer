# Org Workspace

> Code name: `org-workspace`

Clones every repo of a GitHub org into sibling `/workspaces` folders and generates or updates a
multi-root `.code-workspace` file — add this to one "bootstrap" project's `devcontainer.json`
instead of hand-writing `mounts` entries and a workspace file per project (the pattern this
org's own `.dev` repo uses by hand today).

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/github-dev:1": {},
    "ghcr.io/helpers4/devcontainer/org-workspace:1": {}
  }
}
```

That's it — on container start, every non-fork, non-archived repo of the org that your `gh`
auth can see (public and private; the org is auto-detected from this bootstrap repo's own
`origin` remote) is cloned into a sibling `/workspaces/<repo>` folder, and
a `<org>.code-workspace` file is generated at this repo's own root.

**Then, once**: `File > Open Workspace from File...` → select the generated file. VS Code
currently has no way to auto-attach to a specific `.code-workspace` file inside a running
container ([open upstream request](https://github.com/microsoft/vscode-remote-release/issues/9733)) —
this is a one-click step, not something this feature can do for you.

### Leaving some repos out

```jsonc
"ghcr.io/helpers4/devcontainer/org-workspace:1": {
  "exclude": "helpers4.github.io,some-old-repo"
}
```

Applies to auto-discovered and explicit lists alike. A repo excluded after an earlier run had
already linked it loses its `/workspaces/<repo>` symlink and its `.code-workspace` entry; the
clone in the volume is kept, so nothing local is lost.

### Explicit repo list instead of auto-discovery

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/github-dev:1": {},
    "ghcr.io/helpers4/devcontainer/org-workspace:1": {
      "repos": "typescript,devcontainer,action,website"
    }
  }
}
```

Reproducible across rebuilds regardless of what repos the org gains or loses — prefer this over
`autoDiscover` once you know the set you actually want. `repos` always wins over `autoDiscover`
— there's no need to set `autoDiscover` to `false` alongside it.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `org` | string | `""` | GitHub org (or user) to clone repos from. Left empty, detected automatically via `gh repo view` against this bootstrap repo's own `origin` remote. |
| `repos` | string | `""` | Comma-separated explicit repo list (e.g. `"typescript,devcontainer,action"`). Takes precedence over `autoDiscover`. |
| `autoDiscover` | string | `"true"` | Ignored whenever `repos` is set. `"false"`: discover nothing. `"true"` (default): sane defaults (public + private, no forks, no archived). Or a comma-separated token list — `public`, `private`, `internal`, `fork`, `archived` — each present token includes that category, e.g. `"public,fork"` includes public repos and forks but excludes private/internal/archived. |
| `exclude` | string | `""` | Comma-separated repo names never cloned nor listed in the `.code-workspace`, applied to both `repos` and `autoDiscover`. |
| `generateCodeWorkspace` | boolean | `true` | Generate (or update) a multi-root `.code-workspace` file. If one already exists — hand-written, or committed by a teammate — its `folders` list is merged into, not replaced; every other key (`settings`, `extensions`, `launch`, ...) is left untouched. |
| `codeWorkspaceName` | string | `""` | Filename for the generated `.code-workspace`, written at the bootstrap repo's own root. Left empty, defaults to `<org>.code-workspace`. |

## How it works

1. **Build time** (`install.sh`): installs `/usr/local/share/org-workspace/clone-repos.sh` with the
   resolved option values in an `options.env` next to it, and makes `/workspaces` (non-recursively)
   writable by the remote user — the image ships it as `root:root`, and the script creates its
   sibling symlinks directly under it.
2. **Mount**: a Docker named volume (`helpers4-org-workspace-${devcontainerId}`, exclusive to
   this devcontainer) at `/mnt/h4org-workspace` — the actual clones live here, not in the
   container's own ephemeral layer, so a rebuild doesn't wipe out uncommitted local changes in
   any of them.
3. **Every start** (`postStartCommand`): `clone-repos.sh` resolves the org (option, or
   auto-detected), resolves the repo list (`repos`, or `gh repo list` filtered per
   `autoDiscover`), drops anything in `exclude`, and for each repo:
   - Skips it entirely if a file or directory already exists at the sibling path — a manual
     bind-mount, a previous manual clone, anything already there is never touched. (This
     includes a `mounts` entry targeting `/workspaces/<repo>`: don't combine those with this
     Feature, it replaces them.)
   - Re-links it if it's already cloned into the volume from a prior run (the symlink is what a
     rebuild loses, not the volume's own content).
   - Otherwise clones it (`gh repo clone`, retried once) into a temporary directory in the
     volume, renames it into place — so an interrupted clone never leaves a half-populated
     folder mistaken for a finished one — then symlinks `/workspaces/<repo>` → the volume.
4. If `generateCodeWorkspace` is on, enumerates every direct subdirectory of `/workspaces` that
   looks like a real git checkout (has a `.git`) — covering the bootstrap repo itself, anything
   pre-existing, and everything just cloned/linked — and merges it into the `.code-workspace`
   file's `folders` array. Folders already listed are matched by resolved path (`.` and
   `../.dev` are the same folder), hand-written names are kept, and the file's own indentation
   is preserved. A file that isn't plain JSON (VS Code allows comments) is left untouched.

## Reliability

`clone-repos.sh` **always exits 0.** A failing `postStartCommand` makes the devcontainer CLI skip
every lifecycle command after it — for every other Feature and for your own project — so this
script never takes that risk: each failure (unreachable `gh`, a repo you can't access, an
unwritable `/workspaces`, an unparseable workspace file...) is warned about, counted in the final
summary line, and skipped, and a top-level `EXIT` trap backstops anything unforeseen. Transient
`gh` failures (auth or network not ready yet on a fresh start) are retried before giving up.

## Auth

Depends on [`github-dev`](../github-dev) for an authenticated `gh` CLI — both cloning
(`gh repo clone`) and auto-discovery (`gh repo list`) go through it, reusing whatever auth `gh`
already has (SSH-forwarded, a token, or Codespaces' own pre-authenticated `gh`). No separate
auth mechanism to configure. GitHub only, for now — GitLab/Bitbucket/other forges aren't
supported.

## Codespaces

Designed to work there — `gh` is pre-authenticated in Codespaces, and named volumes work the
same way there as locally (a Codespace runs an actual Docker container). Not yet verified in a
live Codespaces environment.

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.1.0**: `autoDiscover` now defaults to `"true"` (still overridden by `repos`); new
  `exclude` option; `clone-repos.sh` can no longer fail the attach and makes `/workspaces`
  writable at build time; atomic clones; the `.code-workspace` merge dedupes by resolved path,
  keeps names and indentation, and never overwrites a JSONC file.
- **v1.0.0**: Initial release.
