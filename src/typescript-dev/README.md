# TypeScript Development Environment (typescript-dev)

TypeScript/JavaScript development setup with indexing, import management, HTML/CSS intelligence, and web tools. Built on top of `essential-dev` for Git, Copilot, and editor enhancements.

## Features

- **TypeScript First**: Latest TypeScript with indexing and import management
- **JavaScript Support**: Full JavaScript editing with quick fixes and auto-imports
- **HTML & CSS Intelligence**: Smart HTML and CSS editing with auto-rename
- **Import Management**: Automatic import/export management and path aliases
- **Web Development Ready**: HTML/CSS tools and code generation utilities
- **Requires essential-dev**: For Git, Copilot, Markdown, and editor enhancements

## What's Included

### TypeScript & JavaScript
- `ms-vscode.vscode-typescript-next` - Latest TypeScript features
- `guilhermetheodoro.typescript-indexing` - Fast TypeScript indexing
- `christian-kohler.npm-intellisense` - npm package autocomplete
- `christian-kohler.path-intellisense` - Path autocomplete
- `YoavBls.pretty-ts-errors` - Pretty TypeScript error output
- `steoates.autoimport` - Auto-import mechanism
- `stringham.move-ts` - Move TypeScript files intelligently

### HTML & CSS Intelligence
- `ecmel.vscode-html-css` - CSS class name completion in HTML
- `formulahendry.auto-rename-tag` - Auto-rename paired HTML tags

### Code Generation
- `quicktype.quicktype` - Generate types from JSON

## Usage

### Basic Setup

> **Note**: This feature requires `essential-dev` for Git, Copilot, and editor tools.

Add to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/typescript-dev:1": {}
    }
}
```

### For Vite/React Projects

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/essential-dev:1": {},
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
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

## Settings

This feature configures the following VS Code settings specific to TypeScript/JavaScript:

```jsonc
{
  // Auto-import configuration
  "javascript.preferences.useAliasesForRenames": false,
  "javascript.updateImportsOnFileMove.enabled": "always",
  "typescript.preferences.useAliasesForRenames": false,
  "typescript.updateImportsOnFileMove.enabled": "always",
  
  // Package manager
  "npm.packageManager": "pnpm"
}
```

## Complementary Features

- **essential-dev** - Core development tools (include this first)
- **vite-plus** - Vite toolchain with Oxc formatter/linter
- **package-auto-install** - Automatic npm/yarn/pnpm install
- **local-mounts** - Mount local Git, SSH, GPG, npm config

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

**General Tools** (included in essential-dev)
- Git integration
- GitHub Copilot
- Markdown support
- File format support (YAML, JSON, CSV)

## Perfect With

This feature pairs perfectly with:
- **[essential-dev](../essential-dev)** - Core development tools (required)
- **[vite-plus](../vite-plus)** - TypeScript + Vite + Oxc/Vitest toolchain
- **[package-auto-install](../package-auto-install)** - Automatic dependency installation
- **[local-mounts](../../deprecated/local-mounts/)** - Git/SSH/GPG configuration
- **[git-absorb](../git-absorb)** - Commit cleanup tools

## License

LGPL-3.0 - See LICENSE file for details
