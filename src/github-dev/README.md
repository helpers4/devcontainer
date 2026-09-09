# GitHub Development Environment

> Code name: `github-dev`

Installs the **GitHub CLI (`gh`)** and the essential GitHub VS Code **platform** extensions (Pull Requests & Issues, GitHub Actions, RemoteHub). Automatically authenticates `gh` if a token is available in the environment.

> **AI assistant:** For GitHub Copilot Chat and the shared commit-message / PR-description generation instructions, use [`copilot-dev`](../copilot-dev) alongside this feature.

## When to use this

Use this when you want `gh` CLI plus the PR/Issues/Actions/RemoteHub VS Code extensions,
without also pulling in Copilot — the two are kept as separate features on purpose.

**Alternatives:**
- The official [`ghcr.io/devcontainers/features/github-cli`](https://github.com/devcontainers/features/tree/main/src/github-cli) feature installs just the CLI, no VS Code extensions and no auto-auth — use that instead if the extensions here aren't what you need.
- Inside GitHub Codespaces, `gh` and a `GITHUB_TOKEN` are already provided by the platform — this feature is still useful there for the VS Code extensions, but the CLI auto-auth step has nothing to do.

## Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/github-dev:1": {}
  }
}
```

With Copilot:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/github-dev:1": {},
    "ghcr.io/helpers4/devcontainer/copilot-dev:1": {}
  }
}
```

## Options

| Option       | Type   | Default  | Description                                               |
|--------------|--------|----------|-----------------------------------------------------------|
| `ghVersion`  | string | `latest` | GitHub CLI version to install (e.g. `2.50.0` or `latest`) |

## What Gets Installed

### GitHub CLI (`gh`)

Installed from [GitHub Releases](https://github.com/cli/cli/releases). Supports `x86_64`, `aarch64`, and `armv7l`.

Common uses inside the devcontainer:

```bash
gh auth status              # Check authentication
gh pr list                  # List open PRs
gh pr create                # Create a PR from current branch
gh pr checkout 123          # Check out a PR locally
gh issue list               # List issues
gh run list                 # List workflow runs
gh run watch                # Watch a running workflow
gh release create v1.0.0    # Create a release
gh repo clone org/repo      # Clone a repository
```

### VS Code Extensions

| Extension                            | Purpose                                                                         |
|--------------------------------------|---------------------------------------------------------------------------------|
| `github.vscode-pull-request-github`  | PR and issue management inside VS Code                                          |
| `github.vscode-github-actions`       | GitHub Actions workflow editor with validation                                  |
| `github.remotehub`                   | Browse remote GitHub repositories without cloning                               |
| `ms-vscode.remote-repositories`      | Open and work on remote repositories without cloning (companion to RemoteHub)   |

## Authentication

### Auto-auth via token (recommended)

Set `GH_TOKEN` (or `GITHUB_TOKEN`) in your environment and `gh` will authenticate automatically on shell startup — no manual `gh auth login` needed.

**Local / DevPod:** add to your `devcontainer.json`:

```jsonc
{
  "remoteEnv": {
    "GH_TOKEN": "${localEnv:GH_TOKEN}"
  }
}
```

Then set `GH_TOKEN` on your host machine (`export GH_TOKEN=ghp_...` in your shell profile).

**GitHub Codespaces:** `GITHUB_TOKEN` is injected automatically — `gh` is authenticated with no extra configuration.

**CI/CD:** set `GH_TOKEN` as a repository or organization secret.

### SSH

Use `dotfiles-sync` to bring your SSH keys into the container.

### Manual

```bash
gh auth login
```

## Version History

- **v1.0.7**: Documentation only, no functional change — added a "When to use this" section
  with alternatives, matching the equivalent sections other features in this catalog already had.
- **v1.0.6**: Internal cleanup, no behavior change — dropped a dead `_BUILD_ARG_GHVERSION`
  fallback in `install.sh`. That prefix is only ever set for the legacy
  `internalVersion: "1"` manifest shape, which this feature (and every other one in this
  repo) never declared — the fallback never fired, `${GHVERSION:-"latest"}` alone always
  resolved the same value.
- **v1.0.5**: Extract Copilot Chat extension and generation instructions into the standalone `copilot-dev` feature (breaking change — add `copilot-dev` to your `devcontainer.json` if you relied on Copilot being bundled here).
- **v1.0.4**: Add shared Copilot Chat pull-request title & description instruction.
- **v1.0.3**: Add shared Copilot Chat commit-message instruction (Conventional Commits + gitmoji).
- **v1.0.2**: Remove deprecated `github.copilot` extension. Add `ms-vscode.remote-repositories`.
- **v1.0.0**: Initial release.
