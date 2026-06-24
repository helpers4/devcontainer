# GitHub Development Environment (github-dev)

Installs the **GitHub CLI (`gh`)** and the essential GitHub VS Code **platform** extensions (Pull Requests & Issues, GitHub Actions, RemoteHub). Automatically authenticates `gh` if a token is available in the environment.

> **AI assistant:** For GitHub Copilot Chat and the shared commit-message / PR-description generation instructions, use [`copilot-dev`](../copilot-dev) alongside this feature.

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

- **v1.0.5**: Extract Copilot Chat extension and generation instructions into the standalone `copilot-dev` feature (breaking change — add `copilot-dev` to your `devcontainer.json` if you relied on Copilot being bundled here).
- **v1.0.4**: Add shared Copilot Chat pull-request title & description instruction.
- **v1.0.3**: Add shared Copilot Chat commit-message instruction (Conventional Commits + gitmoji).
- **v1.0.2**: Remove deprecated `github.copilot` extension. Add `ms-vscode.remote-repositories`.
- **v1.0.0**: Initial release.
