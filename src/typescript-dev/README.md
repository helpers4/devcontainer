# TypeScript Development Environment

> Code name: `typescript-dev`

TypeScript/JavaScript development setup with indexing, import management, HTML/CSS intelligence, and web tools. Built on top of `essential-dev` for Git and editor enhancements; add `copilot-dev`/`github-dev` for Copilot and PR tooling.

## Features

- **TypeScript First**: Latest TypeScript with indexing and import management
- **JavaScript Support**: Full JavaScript editing with quick fixes and auto-imports
- **HTML & CSS Intelligence**: Smart HTML and CSS editing with auto-rename
- **Import Management**: Automatic import/export management and path aliases
- **Web Development Ready**: HTML/CSS tools and code generation utilities
- **Requires essential-dev**: For Git, Markdown, and editor enhancements (`dependsOn`, always installed)

## What's Included

### TypeScript & JavaScript
- `TypeScriptTeam.native-preview` - Latest TypeScript features
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

> **Note**: This feature requires `essential-dev` for Git and editor tools (installed
> automatically via `dependsOn`).

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

- **essential-dev** - Core development tools (installed automatically via `dependsOn`)
- **vite-plus** - Vite toolchain with Oxc formatter/linter
- **package-auto-install** - Automatic npm/yarn/pnpm install
- **dotfiles-sync** - Sync local Git/SSH/GPG/npm config into the container
- **copilot-dev** / **github-dev** - Copilot Chat, AI instructions, `gh` CLI, PR/Issues/Actions

## Not Included (By Design)

**Code Formatters**
- Oxc/Prettier - Use `vite-plus` feature instead

**Testing**
- Vitest - Use `vite-plus` feature instead

**Language-Specific**
- Tailwind CSS - Add as needed per project
- React/Vue snippets - Add per framework
- Cloudflare Workers - Project-specific

**AI Tooling** (not bundled here or in `essential-dev`)
- GitHub Copilot Chat, PR/Issues/Actions - Add `copilot-dev` / `github-dev`

**General Tools** (included in essential-dev)
- Git integration
- Markdown support
- File format support (YAML, JSON, CSV)

## Perfect With

This feature pairs perfectly with:
- **[essential-dev](../essential-dev)** - Core development tools (required, `dependsOn`)
- **[vite-plus](../vite-plus)** - TypeScript + Vite + Oxc/Vitest toolchain
- **[package-auto-install](../package-auto-install)** - Automatic dependency installation
- **[dotfiles-sync](../dotfiles-sync)** - Git/SSH/GPG/npm configuration from the host
- **[git-absorb](../git-absorb)** - Commit cleanup tools

## Version History

- **v1.0.8**: Documentation only, no functional change — this README had drifted from the
  manifest in several ways: `local-mounts` (superseded by `dotfiles-sync` since that feature's
  v1.0.0) was still listed as the recommended companion in four places; Copilot was claimed as
  bundled via `essential-dev`, which stopped being true once Copilot moved to `copilot-dev` /
  `github-dev`; a "Biome - Dedicated feature available" line named a feature that doesn't exist
  in this repo; and the listed TypeScript extension ID (`ms-vscode.vscode-typescript-next`) no
  longer matched the manifest's `TypeScriptTeam.native-preview`. Fixed all four; no
  `install.sh`/manifest change, the manifest's own `description` field already said the right
  thing.
- **v1.0.7**: See commit history for earlier changes.

## License

LGPL-3.0 - See LICENSE file for details
