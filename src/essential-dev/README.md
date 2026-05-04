# Essential Development Environment (essential-dev)

Core development environment with Git integration, GitHub Copilot, Markdown support, and essential editor enhancements. Perfect base for all development projects.

## Features

- **Git Integration**: History, graph visualization, PR support, conventional commits
- **GitHub Copilot**: AI-powered code assistance included
- **Markdown Support**: Full markdown editing with preview and linting
- **Editor Enhancements**: Multi-cursor, code comparison, local history
- **File Format Support**: YAML, JSON, CSV, XML, Makefile support out-of-box
- **Zero Configuration**: Works out-of-the-box, no options needed

## What's Included

### Git & Version Control
- `donjayamanne.githistory` - View and search git log
- `gxl.git-graph-3` - Git graph visualization
- `github.vscode-pull-request-github` - GitHub PR and issue management
- `github.vscode-github-actions` - GitHub Actions support
- `vivaxy.vscode-conventional-commits` - Conventional commits helper

### AI Assistant
- `github.copilot` - AI code completion
- `github.copilot-chat` - AI chat interface

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
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
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
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
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
- Biome - Dedicated feature available

**Testing**
- Vitest - Use `vite-plus` feature instead
