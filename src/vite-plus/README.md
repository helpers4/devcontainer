# Vite+ Development Environment (vite-plus)

Complete Vite+ unified toolchain setup with the `vp` CLI, integrating Vite, Vitest, Oxlint, Oxfmt, Rolldown, tsdown, and Vite Task into a single development experience with VS Code extensions pre-configured.

## Features

- **Vite+ CLI (`vp`)**: Unified toolchain installed via the official installer
- **VS Code Extensions**: Oxc and Vitest extensions pre-configured
- **Oxc Integration**: Ultra-fast linting (Oxlint) and formatting (Oxfmt)
- **Vitest Support**: Test explorer and optimal configuration
- **Smart Defaults**: Editor configured for Vite+ best practices

## What is Vite+?

[Vite+](https://viteplus.dev/) combines [Vite](https://vite.dev/), [Vitest](https://vitest.dev/), [Oxlint](https://oxc.rs/docs/guide/usage/linter.html), [Oxfmt](https://oxc.rs/docs/guide/usage/formatter.html), [Rolldown](https://rolldown.rs/), and [tsdown](https://tsdown.dev/) into a single, unified web development toolchain driven by [Vite Task](https://github.com/voidzero-dev/vite-task).

**Key `vp` commands:**

| Command | Description |
|---------|-------------|
| `vp create` | Scaffold new projects and monorepos |
| `vp install` | Install dependencies using the correct package manager |
| `vp dev` | Start Vite dev server with instant HMR |
| `vp check` | Lint (Oxlint) + format (Oxfmt) + type-check (tsgo) |
| `vp test` | Run tests with Vitest |
| `vp build` | Production builds with Rolldown |
| `vp run` | Execute package.json scripts via Vite Task |
| `vp pack` | Bundle libraries or create standalone binaries |
| `vp env` | Manage Node.js globally and per project |

All you need is `vp` and a `vite.config.ts` at the project root.

Built by VoidZero (creators of Vite, Vitest, and Oxc). Open source under MIT license.

## Usage

### Basic Setup (recommended)

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {}
    }
}
```

This will:
1. Install `vp` (Vite+ unified CLI) for the devcontainer user
2. Install Oxc and Vitest VS Code extensions
3. Configure Oxc as the default formatter
4. Enable format-on-save and auto-fix
5. Set up Vitest test explorer

### With standalone fallback CLIs

If you prefer standalone tools instead of or alongside `vp`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/vite-plus:1": {
            "installVitePlus": true,
            "installVite": true,
            "installVitest": true,
            "installOxc": true
        }
    }
}
```

**Note**: When using `vp`, standalone installs of Vite, Vitest, and Oxc are not needed — `vp` bundles them all.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `installVitePlus` | boolean | `true` | Install Vite+ unified CLI (`vp`) for the devcontainer user (`~/.vite-plus/bin`) |
| `installGlobally` | boolean | `true` | Symlink `vp` into `/usr/local/bin` so it is available system-wide (all users, root, sudo, scripts that don't source the user's profile). Requires `installVitePlus`. |
| `installVite` | boolean | `false` | Install standalone Vite CLI via npm (not needed with `vp`) |
| `installVitest` | boolean | `false` | Install standalone Vitest CLI via npm (not needed with `vp`) |
| `installOxc` | boolean | `false` | Install Oxc language server via npm (not needed with `vp`) |

## VS Code Extensions Included

### Oxc (oxc.oxc-vscode)
- Ultra-fast linting with Oxlint (~50× to ~100× faster than ESLint)
- Prettier-compatible formatting with Oxfmt (up to 30× faster than Prettier)
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
  "editor.defaultFormatter": "oxc.oxc-vscode",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.oxc": "explicit"
  },
  "vitest.enable": true,
  "vitest.commandLine": "npx vitest"
}
```

**Note**: Even though `vp test` can run Vitest, the VS Code Vitest Explorer uses `npx vitest` to ensure the project's local version runs.

## Typical Project Setup with Vite+

### 1. Create a new project

```bash
vp create my-app
```

### 2. Install dependencies

```bash
cd my-app
vp install
```

### 3. Develop

```bash
vp dev
```

### 4. Check code quality (lint + format + type-check)

```bash
vp check         # report issues
vp check --fix   # auto-fix formatting and linting
```

### 5. Run tests

```bash
vp test
```

### 6. Build for production

```bash
vp build
```

### 7. Run scripts via Vite Task

```bash
vp run <script-name>
```

All tasks are configured in your `vite.config.ts`:

```typescript
import { defineConfig } from 'vite'

export default defineConfig({
  plugins: [],
  test: {
    globals: true,
    environment: 'happy-dom',
  },
  run: {
    tasks: {
      'generate:icons': {
        command: 'node scripts/generate-icons.js',
        cache: true,
      },
    },
  },
})
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

- **~1.6× to ~7.7× faster production builds** than Vite 7 (Rolldown)
- **~50× to ~100× faster linting** than ESLint (Oxlint)
- **Up to 30× faster formatting** than Prettier (Oxfmt)
- **Instant HMR** for all file types
- **Automated caching** with Vite Task for monorepo scripts

## Bundled Tools & Versions

Vite+ Alpha ships with:
- Vite 8
- Vitest 4.1
- Oxlint 1.52
- Oxfmt (beta)
- Rolldown
- tsdown

## Troubleshooting

### `vp` command not found

The installer places `vp` in `~/.vite-plus/bin/`. Ensure your shell profile sources it. Open a new terminal session after installation.

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

## Migrating an existing project

Run `vp migrate` in your project root or see the [migration guide](https://viteplus.dev/guide/).

## Links

- **Vite+**: https://viteplus.dev/
- **Vite**: https://vite.dev/
- **Vitest**: https://vitest.dev/
- **Oxc**: https://oxc.rs/
- **Rolldown**: https://rolldown.rs/
- **tsdown**: https://tsdown.dev/
- **Vite Task**: https://github.com/voidzero-dev/vite-task

## License

LGPL-3.0 - See LICENSE file for details
