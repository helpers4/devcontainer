# TypeScript Development Environment (typescript-dev)

Complete TypeScript/JavaScript development setup with Git integration, AI assistance, Markdown support, and essential editor enhancements. Perfect base for all TypeScript/JavaScript projects.

## Features

- **TypeScript First**: Latest TypeScript with indexing and import management
- **Git Integration**: History, graph visualization, PR support, conventional commits
- **GitHub Copilot**: AI-powered code assistance included
- **Markdown Support**: Full markdown editing with preview and linting
- **Editor Enhancements**: Multi-cursor, code comparison, local history
- **File Format Support**: YAML, JSON, CSV support out-of-box
- **Zero Configuration**: Works out-of-the-box, no options needed

## What's Included

### Core Extensions (Always)

**TypeScript & JavaScript**
- `ms-vscode.vscode-typescript-next` - Latest TypeScript features
- `guilhermetheodoro.typescript-indexing` - Fast TypeScript indexing
- `christian-kohler.npm-intellisense` - npm package autocomplete

**Git & Version Control**
- `donjayamanne.githistory` - View git log history
- `gxl.git-graph-3` - Git graph visualization
- `github.vscode-pull-request-github` - GitHub PR support
- `github.vscode-github-actions` - GitHub Actions integration
- `vivaxy.vscode-conventional-commits` - Conventional commits help

**AI Assistant**
- `github.copilot` - AI code completion
- `github.copilot-chat` - AI chat interface

**Editor Enhancements**
- `cardinal90.multi-cursor-case-preserve` - Smart multi-cursor case handling
- `moshfeu.compare-folders` - Folder comparison
- `xyz.local-history` - Local file history

**Markdown & Documentation**
- `yzhang.markdown-all-in-one` - Complete markdown support
- `davidanson.vscode-markdownlint` - Markdown linting
- `bierner.markdown-mermaid` - Mermaid diagram support

**File Format Support**
- `redhat.vscode-yaml` - YAML syntax and validation
- `ms-vscode.vscode-json` - JSON editing
- `mechatroner.rainbow-csv` - CSV/TSV highlighting

## Usage

### Basic Setup

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {}
    }
}
```

That's it! All extensions and settings are applied automatically.

## Recommended Combinations

### For Vite/React Projects

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {
            "includeWebTools": true
        },
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

### For Library Projects

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/h/Vue Projects

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

### For Library Projects

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
        "ghcr.io/helpers4/devcontainer/git-absorb:1": {},
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

### Full Development Stack

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": { "installOxc": true },
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {tor.rulers": [80],
    "editor.quickSuggestions": {
      "comments": "off",
      "strings": "off",
      "other": "off"
    }
  }
}
```

## Not Included (By Design)

**Code Formatters**
- Oxc/Prettier - Use `vite-plus` feature instead
- Biome - Dedicated feature available

**Testing**
- Vitest - Use `vite-plus` feature instead

**Language-Specific**
- Tailwind CSS - Add as needed per project
- React/Vue snippets - Add per framework
- Cloudflare Workers - Project-specific

**Spell Checking**
- Handled by formatter (Oxc) in `vite-plus`

**License Headers**
- Optional via `includeLicenseHeader` option
- Use PSI Header extension

## Perfect With

This feature pairs perfectly with:
- **[vite-plus](../vite-plus)** - TypeScript + Vite + Oxc/Vitest toolchain
- **[package-auto-install](../package-auto-install)** - Automatic dependency installation
- **[local-mounts](../local-mounts)** - Git/SSH/GPG configuration
- **[git-absorb](../git-absorb)** - Commit cleanup tools
- **[shell-history-per-project](../shell-history-per-project)** - Per-project shell history

## Tips

### Git Workflow
- Use `git-graph-3` for visual branch management
- Use `vivaxy.vscode-conventional-commits` for commit message help
- Add `git-absorb` feature for automatic fixup commits

### Markdown Writing
- Enable word wrap for comfortable editing
- Use Mermaid diagrams for architecture
- Markdown linting keeps documentation clean

### Import Management
- TypeScript will auto-update imports when files move
- npm-intellisense helps with package imports

## License

AGPL-3.0 - See LICENSE file for details
