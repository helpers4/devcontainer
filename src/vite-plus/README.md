# Vite+ Development Environment (vite-plus)

Complete Vite+ toolchain setup with VS Code extensions, Oxc formatter/linter, Vitest, and optimized configuration for the unified web development workflow.

## Features

- **VS Code Extensions**: Oxc and Vitest extensions pre-configured
- **Vite CLI**: Optional global Vite installation for quick project scaffolding
- **Vitest CLI**: Optional global Vitest installation for running tests
- **Oxc Integration**: Blazing fast linting and formatting (100x faster than ESLint)
- **Vitest Support**: Test explorer and optimal configuration
- **Smart Defaults**: Editor configured for Vite+ best practices
- **Project Helper**: Includes `vite-plus-init` command for setup guidance

## What is Vite+?

Vite+ is the unified toolchain for web development, combining:

- **Vite** - Lightning-fast dev server and build tool
- **Vitest** - Fast unit test framework
- **Oxc** - Ultra-fast linter and formatter (Rust-based)
- **Rolldown** - Faster bundler
- All-in-one CLI for dev, test, lint, format, and more

Built by the creators of Vite, Vitest, and Oxc for enterprise-scale productivity.

## Usage

### Basic Setup

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {}
    }
}
```

This will:
1. Install Vite, Vitest, and Oxc CLIs globally
2. Install Oxc and Vitest VS Code extensions
3. Configure Oxc as the default formatter
4. Enable format-on-save and auto-fix
5. Set up Vitest test explorer

### With Global CLIs (default)

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/viteplus:1": {
            "installVite": true,
            "installVitest": true,
            "installOxc": true
        }
    }
}
```

This allows you to run `vite`, `vitest`, and `oxc` commands globally without npx.

### With Vite+ Unified CLI (Early Access)

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {
            "installVite": true,
            "installVitest": true,
            "installVitePlus": true,
            "installOxc": true
        }
    }
}
```

**Note**: Vite+ is currently in early access. Register at [viteplus.dev](https://viteplus.dev/). When available, this will install the unified `vite+` CLI.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installVite` | boolean | `true` | Install Vite CLI globally |
| `installVitest` | boolean | `true` | Install Vitest CLI globally |
| `installVitePlus` | boolean | `false` | Install Vite+ unified CLI globally (early access) |
| `installOxc` | boolean | `true` | Install Oxc CLI globally |
| `enableExperimentalFormatter` | boolean | `true` | Enable experimental Oxc formatter features |

## VS Code Extensions Included

### Oxc (oxc.oxc-vscode)
- Ultra-fast linting (up to 100x faster than ESLint)
- Prettier-compatible formatting
- ESLint rule compatibility (600+ rules)
- Type-aware linting support

### Vitest Explorer (vitest.explorer)
- Test discovery and navigation
- Run/debug tests from UI
- Watch mode integration
- Coverage visualization

## VS Code Configuration Applied

```json
{
  "oxc.enable": true,
  "oxc.lint.enable": true,
  "oxc.fmt.enable": true,
  "oxc.fmt.experimental": true,
  "editor.defaultFormatter": "oxc.oxc-vscode",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.oxc": "explicit"
  },
  "vitest.enable": true,
  "vitest.commandLine": "npx vitest"  // Uses local project version if available
}
```

**Note**: Even though Vitest is installed globally, `npx vitest` ensures the test runner uses the project's local version specified in `package.json`, maintaining consistency across the team.

## Project Setup Helper

After the container is created, run:

```bash
vite-plus-init
```

This displays:
- Recommended dependencies for your project type
- Example configuration files
- Setup instructions for React, Vue, or other frameworks

## Typical Project Setup

### 1. Install Dependencies

```bash
# Core Vite+ toolchain
npm install -D vite vitest

# Oxc tools (if not using unified Vite+ CLI)
npm install -D oxc-linter oxc-formatter

# For React
npm install -D @vitejs/plugin-react

# For Vue
npm install -D @vitejs/plugin-vue
```

### 2. Create vite.config.ts

```typescript
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'happy-dom',
  },
})
```

### 3. Create oxc.config.json

```json
{
  "lint": {
    "rules": {
      "no-unused-vars": "error",
      "no-console": "warn"
    }
  },
  "format": {
    "indentWidth": 2,
    "lineWidth": 100
  }
}
```

### 4. Update package.json scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "lint": "oxc lint .",
    "format": "oxc fmt ."
  }
}
```

## Works Great With

Combine with other features for a complete development environment:

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
    "ghcr.io/helpers4/devcontainer/package-auto-install:1": {},
    "ghcr.io/helpers4/devcontainer/local-mounts:1": {},
    "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {},
    "ghcr.io/helpers4/devcontainer/git-absorb:1": {}
  }
}
```

## Supported Frameworks

Vite+ works with all Vite-compatible frameworks:

- ⚛️ **React** - Via `@vitejs/plugin-react`
- 🟢 **Vue** - Via `@vitejs/plugin-vue`
- 🔶 **Svelte** - Via `@sveltejs/vite-plugin-svelte`
- 🔷 **Solid** - Via `vite-plugin-solid`
- 🅰️ **Angular** - Via Angular's Vite integration
- And 20+ more frameworks

## Performance Benefits

- **40x faster builds** than webpack
- **100x faster linting** than ESLint
- **Instant HMR** for all file types
- **Native speed formatting** with Oxc
- **Fast unit tests** with Vitest

## Troubleshooting

### Oxc not formatting

Check that `oxc.oxc-vscode` extension is enabled:
```bash
code --list-extensions | grep oxc
```

### Vitest not discovering tests

Ensure your `vite.config.ts` includes test configuration:
```typescript
export default defineConfig({
  test: {
    include: ['**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}']
  }
})
```

### Global CLI not available

If `oxc` or `vite` commands aren't found, ensure the feature installed with:
```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/viteplus:1": {
      "installOxc": true
    }
  }
}
```
vite`, `vitest`, or `oxc` commands aren't found, ensure the feature installed with:
```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/vite-plus:1": {
      "installVite": true,
      "installVitest": true,/r/nGWebL
- **Vite Documentation**: https://vite.dev/
- **Vitest Documentation**: https://vitest.dev/
- **Oxc Documentation**: https://oxc.rs/
- **VoidZero (Company)**: https://voidzero.dev/

## License

AGPL-3.0 - See LICENSE file for details
