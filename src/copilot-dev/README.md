# GitHub Copilot Development Environment (copilot-dev)

Installs the [GitHub Copilot Chat](https://marketplace.visualstudio.com/items?itemName=GitHub.copilot-chat)
VS Code extension, the `gh copilot` CLI extension, and shared instructions for
commit messages, pull-request descriptions, and code reviews
(Conventional Commits + gitmoji + active repo PR template).

> **Note:** This feature covers the AI assistant only. For `gh` CLI and
> GitHub platform extensions (PR reviews, Actions, RemoteHub), use
> [`github-dev`](../github-dev).

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/copilot-dev:1": {}
  }
}
```

Combined with the platform tooling (recommended — `gh` must be present for the
`gh copilot` extension to install):

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/github-dev:1": {},
    "ghcr.io/helpers4/devcontainer/copilot-dev:1": {}
  }
}
```

## What's included

### Extension

- `github.copilot-chat` — GitHub Copilot Chat AI assistant in VS Code / Cursor

### CLI

- `gh copilot` — GitHub Copilot in the terminal (`gh copilot explain`, `gh copilot suggest`)
  Installed via `gh extension install github/gh-copilot`. Requires `gh` CLI to be present
  (install `github-dev` first, or any other feature that provides `gh`). Skipped with a
  warning if `gh` is not found at build time.

### Shared instructions

Injected via VS Code settings — applied automatically to every Copilot Chat request of the
corresponding type:

| Setting | Trigger | What it enforces |
| --- | --- | --- |
| `commitMessageGeneration.instructions` | Generate Commit Message | Conventional Commits + gitmoji, scopes from `conventionalCommits.scopes` workspace setting |
| `pullRequestDescriptionGeneration.instructions` | Create Pull Request | Same title convention + repo PR template auto-detection with fallback |
| `reviewSelection.instructions` | Review and Comment | Correctness bugs, security issues, simplification - no style feedback |

#### Override or disable

All three are array settings — VS Code merges entries from User, Workspace, and
feature-injected sources. To add your own rules, append an entry in your User or
Workspace settings. To disable a helpers4 default entirely, set the array
explicitly to `[]` in your settings.

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images) for the CLI install; any for IDE-only use
- **Architectures:** amd64, arm64
