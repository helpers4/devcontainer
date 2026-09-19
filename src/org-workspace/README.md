# Org Workspace

> Code name: `org-workspace`

Clones the repos of a GitHub org next to your project and keeps a VS Code multi-root workspace
file up to date. Add it to one project's `devcontainer.json` and the other repos are there when
the container is created.

Use it when several repos of the same org are developed together. For a single repo it does
nothing useful.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/org-workspace:1": {}
  }
}
```

With no options, it takes the org from your project's `origin` remote and clones every repo you
can see, except forks and archived ones. Each repo goes to `/workspaces/<repo>` and a
`<org>.code-workspace` file is created in your project's root folder. Open it once with
**File > Open Workspace from File...**. VS Code cannot open it for you from inside a container.

To pick the repos yourself, or to skip some:

```jsonc
"ghcr.io/helpers4/devcontainer/org-workspace:1": {
  "repos": "typescript,devcontainer,action",
  "exclude": "website"
}
```

A fixed `repos` list gives the same result on every rebuild, even when the org adds or removes
repos.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `org` | string | `""` | GitHub org (or user) to clone from. Empty means the owner of your `origin` remote. |
| `repos` | string | `""` | Comma-separated repos to clone. When set, `autoDiscover` is ignored. |
| `autoDiscover` | string | `"true"` | `"true"`: public and private repos, no forks, no archived. `"false"`: clone nothing. Or a list of categories, e.g. `"public,fork"`: `public`, `private`, `internal`, `fork`, `archived`. |
| `exclude` | string | `""` | Comma-separated repos to skip, whether they come from `repos` or `autoDiscover`. |
| `generateCodeWorkspace` | boolean | `true` | Create or update the `.code-workspace` file. |
| `codeWorkspaceName` | string | `""` | File name. Empty means `<org>.code-workspace`. |

## What it does

1. **At build**, `install.sh` installs the script and makes `/workspaces` writable for your user.
2. **When the container is created**, the script:
   - clones each repo into a Docker volume (`helpers4-org-workspace-${devcontainerId}`, mounted
     at `/mnt/h4org-workspace`) and links it from `/workspaces/<repo>`. The clones live in the
     volume, so a rebuild keeps your local branches and uncommitted work;
   - skips any repo that already has a folder in `/workspaces`;
   - adds the new folders to the `.code-workspace` file. Names and settings you wrote in it are
     kept, and a folder listed twice under different paths (`.` and `../my-project`) counts
     once.

A failed clone, or no access to a repo, prints a warning and the rest carries on. The script
always exits 0, because a failing lifecycle command would stop the ones after it.

## Cleaning up

A repo that is no longer wanted (you excluded it, or it was archived or deleted upstream) loses
its link in `/workspaces` and its entry in the workspace file. Its clone is deleted only when git
confirms nothing would be lost: no uncommitted or ignored files (except `node_modules`), no stash,
no commit missing from the remote. Otherwise the clone stays in the volume and a warning says so.

Nothing is removed when the list of repos looks incomplete: when `gh repo list` fails, or when it
returns nothing.

## Limits

- GitHub only, and one org per project.
- The repos are cloned when the container is created. A repo added to the org later shows up
  after the next rebuild.
- A `.code-workspace` file with comments is left as it is, because it cannot be edited safely.
  Otherwise the file is rewritten the way VS Code writes it: tabs, no final newline.
- Needs an authenticated `gh`, which [`github-dev`](../github-dev) provides.
- Don't also mount volumes on `/workspaces/<repo>` yourself. Those folders would be seen as
  already present and skipped.

## Codespaces

Should work, since `gh` is already authenticated there and named volumes behave the same. Not
tested in a real Codespace yet.

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.0.1**: `autoDiscover` defaults to `"true"`. New `exclude` option. The script no longer
  fails the container when something goes wrong, and `/workspaces` is writable at build time. It
  now runs when the container is created instead of at every start, and removes repos that are
  no longer wanted.
- **v1.0.0**: Initial release.
