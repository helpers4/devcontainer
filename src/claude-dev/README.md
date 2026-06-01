# Claude Code Development Environment (claude-dev)

Installs the [Claude Code](https://www.anthropic.com/claude-code) IDE extension
across supported editors so every devcontainer gets AI-assisted coding powered
by Claude out of the box.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {}
  }
}
```

## IDE support

| Editor | Status | ID |
|--------|--------|----|
| VS Code | ✅ | `anthropic.claude-code` |
| Cursor | ✅ | `anthropic.claude-code` (same registry as VS Code) |
| JetBrains (IntelliJ, WebStorm…) | 🔜 | pending `xmlId` confirmation — marketplace page: [plugin/27310](https://plugins.jetbrains.com/plugin/27310) (vendor: Anthropic) |
| Zed | 🔜 | no standard devcontainer customization format yet |

## How it works

The feature declares IDE extensions via the `customizations` field in
`devcontainer-feature.json`. The devcontainer runtime (VS Code Remote Containers,
Cursor, JetBrains Gateway…) reads this field and installs the listed extensions
automatically — no manual step required.

## OS and Architecture Support

- **OS:** any (no OS-level installation — pure IDE configuration)
- **Architectures:** amd64, arm64
