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
    "ghcr.io/helpers4/devcontainer/org-workspace:1": {
      "autoDiscover": "public"
    }
  }
}
```

That's it — on container start, every public repo of the org (auto-detected from this
bootstrap repo's own `origin` remote) is cloned into a sibling `/workspaces/<repo>` folder, and
a `<org>.code-workspace` file is generated at this repo's own root.

**Then, once**: `File > Open Workspace from File...` → select the generated file. VS Code
currently has no way to auto-attach to a specific `.code-workspace` file inside a running
container ([open upstream request](https://github.com/microsoft/vscode-remote-release/issues/9733)) —
this is a one-click step, not something this feature can do for you.

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
`autoDiscover` once you know the set you actually want.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `org` | string | `""` | GitHub org (or user) to clone repos from. Left empty, detected automatically via `gh repo view` against this bootstrap repo's own `origin` remote. |
| `repos` | string | `""` | Comma-separated explicit repo list (e.g. `"typescript,devcontainer,action"`). Takes precedence over `autoDiscover`. |
| `autoDiscover` | string | `"false"` | Only used when `repos` is empty. `"false"`: discover nothing. `"true"`: sane defaults (public + private, no forks, no archived). Or a comma-separated token list — `public`, `private`, `internal`, `fork`, `archived` — each present token includes that category, e.g. `"public,fork"` includes public repos and forks but excludes private/internal/archived. |
| `generateCodeWorkspace` | boolean | `true` | Generate (or update) a multi-root `.code-workspace` file. If one already exists — hand-written, or committed by a teammate — its `folders` list is merged into, not replaced; every other key (`settings`, `extensions`, `launch`, ...) is left untouched. |
| `codeWorkspaceName` | string | `""` | Filename for the generated `.code-workspace`, written at the bootstrap repo's own root. Left empty, defaults to `<org>.code-workspace`. |

## How it works

1. **Build time** (`install.sh`): generates `/usr/local/share/org-workspace/clone-repos.sh`
   with the resolved option values baked in.
2. **Mount**: a Docker named volume (`helpers4-org-workspace-${devcontainerId}`, exclusive to
   this devcontainer) at `/mnt/h4org-workspace` — the actual clones live here, not in the
   container's own ephemeral layer, so a rebuild doesn't wipe out uncommitted local changes in
   any of them.
3. **Every start** (`postStartCommand`): `clone-repos.sh` resolves the org (option, or
   auto-detected), resolves the repo list (`repos`, or `gh repo list` filtered per
   `autoDiscover`), and for each repo:
   - Skips it entirely if a file or directory already exists at the sibling path — a manual
     bind-mount, a previous manual clone, anything already there is never touched.
   - Re-links it if it's already cloned into the volume from a prior run (the symlink is what a
     rebuild loses, not the volume's own content).
   - Otherwise clones it (`gh repo clone`) into the volume, then symlinks
     `/workspaces/<repo>` → the volume.
4. If `generateCodeWorkspace` is on, enumerates every direct subdirectory of `/workspaces` that
   looks like a real git checkout (has a `.git`) — covering the bootstrap repo itself, anything
   pre-existing, and everything just cloned/linked — and writes or merges that list into the
   `.code-workspace` file's `folders` array.

Best-effort throughout: a repo that can't be resolved or cloned is warned about and skipped,
never treated as fatal for the rest of the run or for the attach itself.

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

- **v1.0.0**: Initial release.
