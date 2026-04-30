# GitHub Development Environment (github-dev)

Installs the **GitHub CLI (`gh`)** and adds the essential GitHub VS Code extensions (Copilot Chat, Pull Requests & Issues, GitHub Actions, RemoteHub). Automatically authenticates `gh` if a token is available in the environment.

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/github-dev:1": {}
    }
}
```

Combine with `essential-dev` for a complete development environment:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/github-dev:1": {}
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `ghVersion` | string | `latest` | GitHub CLI version to install (e.g. `2.50.0` or `latest`) |

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

| Extension | Purpose |
|-----------|---------|
| `github.copilot-chat` | AI chat assistant and code completions (replaces the deprecated `github.copilot` extension) |
| `github.vscode-pull-request-github` | PR and issue management inside VS Code |
| `github.vscode-github-actions` | GitHub Actions workflow editor with validation |
| `github.remotehub` | Browse remote GitHub repositories without cloning |
| `ms-vscode.remote-repositories` | Open and work on remote repositories without cloning (companion to RemoteHub) |

## Copilot Chat commit-message guidance

This feature ships a shared **Copilot Chat commit-message instruction** for the helpers4 organization (Conventional Commits + gitmoji). It is injected via `github.copilot.chat.commitMessageGeneration.instructions`.

The instruction does **not** hardcode the list of allowed scopes — instead, it tells Copilot Chat to look up the workspace setting `conventionalCommits.scopes` defined in each repo's `.vscode/settings.json`. This keeps a single source of truth per repo (used by both the *Conventional Commits* extension UI and the AI commit-message generator).

## Copilot Chat pull-request title & description guidance

This feature also ships a shared instruction for **PR titles and descriptions** via `github.copilot.chat.pullRequestDescriptionGeneration.instructions`:

- The PR **title** follows the same Conventional Commits + gitmoji format as commit messages, and reads its scope list from the same `conventionalCommits.scopes` workspace setting.
- The PR **body** is **repo-agnostic**: Copilot looks for the active repository's own template (`.github/PULL_REQUEST_TEMPLATE.md`, `pull_request_template.md`, files under `.github/PULL_REQUEST_TEMPLATE/`, etc.) and reproduces its sections, headings, and checkbox labels verbatim — ticking checkboxes based on the diff. If the workspace also bundles an org-level `.github` repo as a sibling folder, that template is used as a fallback. If no template is found anywhere, a minimal default structure (Description / Changes / How Has This Been Tested? / Related Issues) is used.

This means external users adopting this feature get the format guarantees without having to adopt helpers4's specific template.

### Override or disable

Both `commitMessageGeneration.instructions` and `pullRequestDescriptionGeneration.instructions` are array settings — VS Code merges entries from User, Workspace, and feature-injected sources. To override, add your own entry in your User or Workspace settings; to disable a helpers4 default, set the corresponding array explicitly to `[]` in your settings (this clears feature-injected items).

## Authentication

### Auto-auth via token (recommended)

Set `GH_TOKEN` (or `GITHUB_TOKEN`) in your environment and `gh` will authenticate automatically on shell startup — no manual `gh auth login` needed.

**Local / DevPod:** add to your `devcontainer.json`:

```json
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

- **v1.0.3**: Add shared Copilot Chat pull-request title & description instruction. PR titles follow the same Conventional Commits + gitmoji format as commits; PR bodies follow the **active repository's own** PR template when available (with sibling org `.github` repo as fallback), and gracefully fall back to a minimal default otherwise — repo-agnostic, no helpers4-specific assumptions.
- **v1.0.2**: Add shared Copilot Chat commit-message instruction (Conventional Commits + gitmoji) for the helpers4 org. The instruction references each repo's `conventionalCommits.scopes` workspace setting instead of hardcoding scopes, removing duplication across the 6 helpers4 repos.
- **v1.0.1**: Remove deprecated `github.copilot` extension (superseded by `github.copilot-chat`). Add `ms-vscode.remote-repositories` (companion to RemoteHub).
- **v1.0.0**: Initial release. gh CLI, Copilot, Copilot Chat, Pull Requests & Issues, GitHub Actions, RemoteHub extensions. Auto-auth via `GH_TOKEN`/`GITHUB_TOKEN`. Extracted from `essential-dev`.
