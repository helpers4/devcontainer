# Automatic File Headers

Automatically configures VS Code with customizable file headers based on your project's license, company, and team information.

## Features

✨ **Two header styles**:
- **Simple** (default): Standard 3-line header with project, copyright, and license
- **Custom**: Your own multi-line header template

🔧 **Flexible configuration**:
- Project name (required)
- License in SPDX format (default: MIT)
- Company/organization name (optional)
- Copyright start year (optional, defaults to current year)
- Contributors list (optional)

🚀 **Helper script**: `h4-init-headers` command to initialize headers in any project

## Installation

Add to your `.devcontainer/devcontainer.json`:

### Simple Header (Default)

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "projectName": "my-awesome-project",
      "license": "MIT",
      "company": "Acme Corp",
      "sinceYear": "2024"
    }
  }
}
```

This generates headers like:

```javascript
// This file is part of my-awesome-project.
// Copyright (C) 2024-2026 Acme Corp
// SPDX-License-Identifier: MIT
```

### Custom Header

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "headerType": "custom",
      "projectName": "my-awesome-project",
      "customHeaderLines": "/**\n * @project my-awesome-project\n * @author Team\n * @license MIT\n */"
    }
  }
}
```

## Usage

After the container is created, initialize headers in your project:

```bash
h4-init-headers
```

This command:
1. Reads your feature configuration
2. Generates appropriate header settings
3. Creates or merges with `.vscode/settings.json`

## Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `headerType` | string | `simple` | Header style: `simple` or `custom` |
| `projectName` | string | *required* | Project name for header |
| `license` | string | `MIT` | SPDX license identifier |
| `company` | string | *optional* | Company or organization name |
| `contributors` | string | *optional* | Comma-separated contributor names |
| `sinceYear` | string | *current year* | Copyright start year |
| `customHeaderLines` | string | *required for custom* | Custom header lines (linefeed separated) |

## Examples

### TypeScript Project with AGPL License

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "projectName": "helpers4-typescript",
      "license": "AGPL-3.0",
      "company": "helpers4",
      "sinceYear": "2025",
      "contributors": "Alice, Bob, Charlie"
    }
  }
}
```

### Apache Licensed Corporate Project

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "projectName": "enterprise-app",
      "license": "Apache-2.0",
      "company": "ACME Industries",
      "sinceYear": "2020"
    }
  }
}
```

### Custom Header with Specific Format

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "headerType": "custom",
      "projectName": "my-lib",
      "customHeaderLines": "/*!\n * @file\n * @description Custom file header\n * @version 1.0.0\n */"
    }
  }
}
```

## What Gets Created

After running `h4-init-headers`:

- **`.vscode/settings.json`**: Updated with file header configuration
- **Feature configuration**: Stored in `/etc/h4-auto-header/config.json` (system-wide)

## Typical Workflow

```bash
# 1. Add feature to devcontainer.json
# 2. Rebuild container (feature runs automatically)
# 3. Run initialization command
h4-init-headers

# 4. Start creating files - headers will be added automatically
# 5. Save files - headers auto-update on file changes
```

## Integrating with Your Workflow

### Auto-initialize on Container Creation

Add `postCreateCommand` to auto-initialize:

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/auto-header:latest": {
      "projectName": "my-project",
      "license": "MIT"
    }
  },
  "postCreateCommand": "h4-init-headers"
}
```

### Multiple Projects

Run `h4-init-headers` in each project directory:

```bash
cd project-a && h4-init-headers
cd project-b && h4-init-headers
```

The script will use the appropriate `.vscode` directory for each project.

## Common License Identifiers

- `MIT` - MIT License
- `Apache-2.0` - Apache License 2.0
- `GPL-3.0` - GNU General Public License v3.0
- `AGPL-3.0` - GNU Affero General Public License v3.0
- `BSD-2-Clause` - BSD 2-Clause License
- `BSD-3-Clause` - BSD 3-Clause License
- `ISC` - ISC License
- `MPL-2.0` - Mozilla Public License 2.0

See [SPDX License List](https://spdx.org/licenses/) for complete list.

## Troubleshooting

### Script not found

```bash
# Ensure feature was installed
which h4-init-headers

# If not found, reinstall feature or recreate container
```

### Settings not applied

```bash
# Verify configuration file exists
cat /etc/h4-auto-header/config.json

# Re-run initialization
h4-init-headers

# Check VS Code has correct workspace open
```

### Headers not auto-inserting

1. Verify file header support is installed and enabled
2. Check `.vscode/settings.json` exists and has correct config
3. Restart VS Code or reload window: `Ctrl+Shift+P` → "Developer: Reload Window"

### Year not updating automatically

The headers are generated with fixed copyright years (e.g., `2024-2026`) at the time the devcontainer is created. If you want the year to automatically update:

1. Rebuild the devcontainer to regenerate the configuration with current year
2. Or manually update the copyright years in `.vscode/settings.json`

## Integration with helpers4 Projects

This feature complements the helpers4 development environment:

- **typescript**: Work with properly licensed utility functions
- **devcontainer**: Ensure consistent headers across team
- **action**: Validate file headers in CI/CD pipelines

## License

Copyright (c) 2025 helpers4  
Licensed under AGPL-3.0 - see LICENSE file for details

## See Also

- [psi-header Extension](https://marketplace.visualstudio.com/items?itemName=psioniq.psi-header)
- [SPDX License Identifiers](https://spdx.org/licenses/)
- [Conventional Commits](https://www.conventionalcommits.org/)
