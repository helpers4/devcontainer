# Peon Ping — AI Agent Sound Notifications (peon-ping)

Installs [peon-ping](https://peonping.com/) and the [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet) VS Code extension for game character voice notifications when your AI coding agent finishes or needs permission.

Supports **Claude Code**, **GitHub Copilot**, **Cursor**, **OpenAI Codex**, and [many more IDEs](https://github.com/PeonPing/peon-ping#multi-ide-support).

## Features

- **Sound notifications**: Warcraft, StarCraft, Portal, Zelda and 165+ sound packs
- **Multi-IDE hooks**: Claude Code (built-in), Copilot, Cursor, Codex via adapters
- **Peon Pet extension**: Animated orc sidebar companion reacting to agent events
- **Devcontainer-aware**: Auto-routes audio to host via relay (`host.docker.internal:19998`)
- **Non-interactive**: Fully automated, idempotent installation

## Usage

### Basic Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {}
    }
}
```

This installs peon-ping with the default 5 packs (peon, peasant, sc_kerrigan, sc_battlecruiser, glados), registers Claude Code hooks, and installs the Peon Pet VS Code extension.

### With All Packs

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {
            "packs": "all"
        }
    }
}
```

### Copilot Only + Specific Packs

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {
            "packs": "peon,glados,murloc",
            "ideSetup": "vscode",
            "volume": "0.3"
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `packs` | string | `default` | Sound packs: `default` (5 curated), `all` (165+), or CSV (e.g. `peon,glados,murloc`) |
| `noRc` | boolean | `true` | Skip `.bashrc`/`.zshrc` modifications (recommended for devcontainers) |
| `ideSetup` | string | `vscode` | IDEs to configure: `all` (vscode + cursor + codex), `none`, or CSV (e.g. `vscode,cursor`) |
| `volume` | string | `0.5` | Default volume level (0.0–1.0) |

## Audio in Devcontainers

peon-ping auto-detects devcontainer environments and routes audio to your host machine via a lightweight relay. **You must start the relay on your host:**

```bash
# On your HOST machine — not inside the container
peon relay --daemon
```

The container sends audio requests to `host.docker.internal:19998` automatically. No port forwarding configuration needed.

### Relay Commands

```bash
peon relay --daemon       # Start in background
peon relay --stop         # Stop relay
peon relay --status       # Check status
peon relay --port=12345   # Custom port
```

> **Note**: Install peon-ping on your host machine first: `brew install PeonPing/tap/peon-ping` (macOS) or `curl -fsSL https://peonping.com/install | bash`

## IDE-Specific Setup

### Claude Code

Hooks are registered automatically by the peon-ping installer in `~/.claude/settings.json`. No extra configuration needed.

### GitHub Copilot

The feature installs a helper script. Run it from your workspace root to generate `.github/hooks/hooks.json`:

```bash
peon-ping-copilot-setup
```

Or add it to your devcontainer.json:

```json
{
    "postCreateCommand": "peon-ping-copilot-setup"
}
```

This creates hooks for `SessionStart`, `UserPromptSubmit`, `PostToolUse`, and `Stop` events using the Copilot adapter.

### Cursor

When `setupCursorHooks` is `true`, hooks are written to `~/.cursor/hooks.json` automatically. Events: `afterAgentResponse`, `stop`.

### OpenAI Codex

When `setupCodexHooks` is `true`, the notify config is added to `~/.codex/config.toml` automatically.

### Other IDEs

peon-ping provides adapters for [15+ IDEs](https://github.com/PeonPing/peon-ping#multi-ide-support) including Amp, Gemini CLI, Windsurf, Kiro, OpenCode, and more. After installation, adapters are available at `~/.claude/hooks/peon-ping/adapters/`.

## Peon Pet Extension

The [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet) VS Code extension adds an animated orc to your sidebar that reacts to peon-ping events. It polls `~/.claude/hooks/peon-ping/.state.json` every 200ms — no daemon needed.

Settings:
- `peon-pet.size`: `small`, `medium` (default), or `large`
- `peon-pet.character`: `orc` (default)

## Quick Controls (Inside Container)

```bash
peon status               # Check if active
peon pause                # Mute sounds
peon resume               # Unmute
peon volume 0.3           # Change volume
peon packs use glados     # Switch pack
peon packs list           # List installed packs
```
