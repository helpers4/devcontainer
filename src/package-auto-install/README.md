# Automatic Package Installation (package-auto-install)

Automatically detects and runs npm/yarn/pnpm install in non-interactive mode after container creation.

## Features

- **Automatic detection**: Detects package manager based on lockfile (pnpm-lock.yaml, yarn.lock, package-lock.json)
- **Corepack support**: Automatically installs and enables corepack if `packageManager` field is found in package.json (required for Node 24+)
- **Non-interactive mode**: Sets `CI=true` to avoid prompts (e.g., pnpm won't ask to delete node_modules)
- **Smart command selection**: Uses `npm ci`, `pnpm install --frozen-lockfile`, or `yarn install --immutable` when lockfiles exist
- **Flexible configuration**: Override package manager, command, and working directory
- **Skip if exists**: Optionally skip installation if node_modules already exists
- **Multi-root support**: Auto-discover VS Code/Cursor `.code-workspace` and IntelliJ `.idea/modules.xml` project files to install across all workspace folders

## Usage

### Basic Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {}
    }
}
```

This will:
1. Detect the package manager from lockfile
2. Run the appropriate install command automatically
3. Set `CI=true` to prevent interactive prompts

### Remove Manual postCreateCommand

If you have this in your devcontainer.json, you can now remove it:

```json
{
    "postCreateCommand": "CI=true pnpm install"  // ❌ Not needed anymore
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `command` | string | `auto` | Installation command: `install`, `ci`, or `auto` to detect |
| `packageManager` | string | `auto` | Package manager: `npm`, `yarn`, `pnpm`, or `auto` to detect |
| `workingDirectory` | string | `/workspaces/${localWorkspaceFolderBasename}` | Directory where to run install. Overridden by `directories`. Used as fallback scan root when `autoDiscover` finds no workspace files. |
| `skipIfNodeModulesExists` | boolean | `false` | Skip if node_modules exists |
| `additionalArgs` | string | `""` | Additional arguments for install command |
| `directories` | string | `""` | Comma-separated list of directories to install in. Overrides `workingDirectory` and `autoDiscover`. |
| `autoDiscover` | boolean | `false` | Scan `/workspaces` for VS Code/Cursor `.code-workspace` and IntelliJ `.idea/modules.xml` files and install in every discovered folder with a `package.json`. |

## Examples

### Force specific package manager

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "packageManager": "pnpm"
        }
    }
}
```

### Use npm ci explicitly

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "packageManager": "npm",
            "command": "ci"
        }
    }
}
```

### Skip if node_modules exists (useful for rebuilds)

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "skipIfNodeModulesExists": true
        }
    }
}
```

### Pass additional arguments

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "additionalArgs": "--ignore-scripts"
        }
    }
}
```

### Custom working directory

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "workingDirectory": "/workspace/frontend"
        }
    }
}
```

### VS Code / Cursor multi-root workspace

When your devcontainer uses a `.code-workspace` file with multiple folders, enable `autoDiscover` to install packages in every discovered folder:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "autoDiscover": true
        }
    }
}
```

The feature scans `/workspaces` (depth 3) for `*.code-workspace` files, parses the `folders[].path` array, resolves relative paths, and runs the appropriate package manager in each folder that contains a `package.json`. Each folder may use a different package manager — detection runs independently per folder.

### IntelliJ IDEA multi-module project

`autoDiscover: true` also scans for `.idea/modules.xml` files (depth 4) and extracts module root directories from the `filepath` attributes.

### Explicit list of directories

For any IDE that does not have a parseable workspace file (Zed, Neovim, etc.) or when you want precise control:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "directories": "/workspaces/frontend,/workspaces/backend,/workspaces/shared"
        }
    }
}
```

`directories` takes precedence over both `workingDirectory` and `autoDiscover`.

## How It Works
Corepack Support (Node 24+)

If your `package.json` contains a `packageManager` field (e.g., `"packageManager": "pnpm@9.0.0"`):

1. The feature checks if corepack is available
2. If not, it installs corepack globally with `npm install -g corepack`
3. Enables corepack with `corepack enable`
4. Corepack then automatically installs and uses the exact package manager version specified

This is particularly important for Node 24+ where corepack is no longer included by default.

### 
### Package Manager Detection

The feature detects the package manager in this order:

1. **From `packageManager` field in package.json** (highest priority)
   - Example: `"packageManager": "pnpm@9.0.0"` → uses **pnpm**
   - This is the most reliable and modern approach
2. **From lockfiles**:
   - `pnpm-lock.yaml` → uses **pnpm**
   - `yarn.lock` → uses **yarn**
   - `package-lock.json` → uses **npm**
3. **Default**: Falls back to **npm** if nothing is detected

### Command Selection (when `command: "auto"`)

For each package manager:

- **npm**: Uses `npm ci` if package-lock.json exists, otherwise `npm install`
- **pnpm**: Uses `pnpm install --frozen-lockfile` if pnpm-lock.yaml exists, otherwise `pnpm install`
- **yarn**: 
  - Yarn 2+: Uses `yarn install --immutable` if yarn.lock exists
  - Yarn 1.x: Uses `yarn install --frozen-lockfile` if yarn.lock exists

### CI Mode

The feature sets `CI=true` environment variable, which:

- **pnpm**: Automatically removes old node_modules without prompting
- **npm**: Enables strict mode in `npm ci`
- **yarn**: Enables immutable installs

## Execution Order

The feature uses `installsAfter` to ensure it runs after:
- `ghcr.io/devcontainers/features/common-utils`
- `ghcr.io/devcontainers/features/node`

The actual package installation runs in `postCreateCommand`, which is the last lifecycle hook after all features are installed.

## Troubleshooting

### Installation not running

Check that:
- `package.json` exists in the working directory
- The package manager is installed (use node feature or appropriate base image)

### Wrong package manager detected

Force the package manager explicitly:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/package-auto-install:1": {
            "packageManager": "pnpm"
        }
    }
}
```

### Installation fails

Check the container logs during creation. The feature will show the exact command being run and any errors.

### Need to debug

You can manually run the installation script:

```bash
/usr/local/bin/devcontainer-package-install
```

## Version History

- **v1.0.2**: Added `autoDiscover` (scan VS Code/Cursor `.code-workspace` and IntelliJ `.idea/modules.xml`) and `directories` (explicit comma-separated list) options for multi-root workspace support. Each folder runs package manager detection independently.
- **v1.0.1**: Added corepack support for Node 24+ (`packageManager` field in package.json).
- **v1.0.0**: Initial release.

## License

LGPL-3.0 - See LICENSE file for details
