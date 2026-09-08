# Essential Development Environment

> Code name: `essential-dev`

Core development environment with Git integration, Markdown support, and essential editor enhancements. Perfect base for all development projects.

> **Also included automatically:** helpers4's self-heal mechanism, working on both local and
> cloud containers. It does its best to fix broken paths and a missing commit-signing key, with
> nothing to set up on your end. It comes from this feature's dependency on `helpers4-common` —
> you never need to add that feature yourself.

## Features

- **Git Integration**: History and graph visualization
- **Markdown Support**: Full markdown editing with preview and linting
- **Editor Enhancements**: Multi-cursor, code comparison, local history
- **File Format Support**: YAML, JSON, CSV, XML, Makefile support out-of-box
- **Zero Configuration**: Works out-of-the-box, no options needed

## What's Included

### Git & Version Control
- `donjayamanne.githistory` - View and search git log
- `the0807.git-graph-plus` - Git graph visualization

Conventional Commits + gitmoji guidance is provided as AI instructions by the
`copilot-dev` feature, not a standalone linting extension — add `copilot-dev`
for that.

### AI Assistant

Not included here — add the `copilot-dev` feature for GitHub Copilot Chat and
AI generation instructions, or `github-dev` for the `gh` CLI and GitHub pull
request/issue/Actions extensions.

### Editor Enhancements
- `cardinal90.multi-cursor-case-preserve` - Smart multi-cursor case handling
- `moshfeu.compare-folders` - Folder comparison
- `xyz.local-history` - Local file history
- `editorconfig.editorconfig` - EditorConfig support

### Markdown & Documentation
- `yzhang.markdown-all-in-one` - Complete markdown support
- `davidanson.vscode-markdownlint` - Markdown linting
- `bierner.markdown-mermaid` - Mermaid diagram support

### File Format Support
- `redhat.vscode-yaml` - YAML syntax and validation
- `redhat.vscode-xml` - XML support
- `ms-vscode.vscode-json` - JSON editing
- `adamraichu.zip-viewer` - ZIP archive preview
- `mechatroner.rainbow-csv` - CSV/TSV highlighting
- `ms-vscode.makefile-tools` - Makefile support

## Usage

### Basic Setup

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {}
    }
}
```

That's it! All extensions and settings are applied automatically.

## Combining with Other Features

### With TypeScript Development

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
    }
}
```

### Full Development Stack

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/vite-plus:1": { "installOxc": true },
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
    }
}
```

## Terminal Shell Integration

[VS Code Shell Integration](https://code.visualstudio.com/docs/terminal/shell-integration) is automatically enabled with this feature. It provides:

### Benefits
- **Command Awareness**: VS Code tracks commands executed in the terminal
- **Exit Codes**: Visual indicators for success (✓) and failure (✗)
- **Run History**: Easy navigation through previously executed commands
- **Smart Suggestions**: Context-aware suggestions for frequently used commands
- **Decorations**: Visual separators between commands for cleaner display

### Supported Shells
- **zsh** (primary)
- **bash**
- **fish**

All shells are automatically detected and configured when available.

## Not Included (By Design)

**Language-Specific Tools**
- TypeScript indexing - Use `typescript-dev` feature instead
- Tailwind CSS - Add as needed per project
- React/Vue snippets - Add per framework

**Code Formatters**
- Oxc/Prettier - Use `vite-plus` feature instead

**Testing**
- Vitest - Use `vite-plus` feature instead

## Version History

- **v1.2.1**: Documentation only, no functional change — `github.copilot`, `github.copilot-chat`
  and `vivaxy.vscode-conventional-commits`, along with the PR-support and conventional-commits
  claims in the intro and Features list, haven't shipped with this feature's manifest since the
  AI/Copilot tooling was extracted into `github-dev` and `copilot-dev`; the README now matches
  the manifest and points there instead.
- **v1.2.0**: Documentation only, no functional change — mentions that `helpers4-common`'s
  automatic git-config self-heal (see above) comes along with this feature.
