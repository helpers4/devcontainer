# Peon Ping — AI Agent Sound Notifications (peon-ping)

Installs [peon-ping](https://peonping.com/) and the [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet) VS Code extension for game character voice notifications when your AI coding agent finishes or needs permission.

Supports **Claude Code**, **GitHub Copilot**, **Cursor**, **OpenAI Codex**, and [many more IDEs](https://github.com/PeonPing/peon-ping#multi-ide-support).

## Features

- **Sound notifications**: Warcraft, StarCraft, Portal, Zelda and 165+ sound packs
- **Multi-IDE hooks**: Claude Code (built-in), Copilot, Cursor, Codex via adapters
- **Peon Pet extension**: Animated orc sidebar companion reacting to agent events
- **Devcontainer-aware**: Routes audio to host via relay (`host.docker.internal:19998`) — needs a `runArgs` addition on native Linux Docker, see "Audio in Devcontainers" below
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

The container sends audio requests to `host.docker.internal:19998`.

**On native Linux Docker (not Docker Desktop), this needs one more line — `host.docker.internal` doesn't resolve out of the box there.** Docker Desktop (macOS/Windows) injects that DNS entry automatically; plain Linux Docker doesn't. Verified directly from inside a real devcontainer on Linux Docker: `getent hosts host.docker.internal` returns nothing without this. Add to your `devcontainer.json`:

```jsonc
{
  "runArgs": ["--add-host=host.docker.internal:host-gateway"]
}
```

This can't be added by the feature itself — `runArgs` is a top-level `devcontainer.json` property, not something a Feature's manifest can inject (same class of limitation as `initializeCommand`, see `helpers4/devcontainer`'s `AGENTS.md`). It's harmless to add unconditionally, including on Docker Desktop where the entry already resolves another way — `--add-host` just adds a redundant, consistent one.

### Verifying it actually works

1. On the **host**: `peon relay --daemon`, then `peon relay --status` to confirm it's listening.
2. Add the `runArgs` line above to `devcontainer.json` and rebuild the container.
3. Inside the **container**: `getent hosts host.docker.internal` should now print an IP (previously empty on native Linux Docker).
4. Inside the **container**: check the relay port is actually reachable, not just the hostname resolving — e.g. `(echo > /dev/tcp/host.docker.internal/19998) 2>&1 && echo reachable || echo unreachable`. If this says `unreachable` even after step 3 resolves, the relay on the host is likely bound to `127.0.0.1` only (not visible from the container's network) rather than a devcontainer/Feature-side problem — check `peon relay --status` output on the host for its bind address.
5. Trigger a real notification (finish an agent turn) and confirm you hear it.

If step 4 fails, that's outside what this feature (or any devcontainer Feature) can fix — it's the host-side relay's own bind address, controlled by the `peon` CLI itself, not this repo.

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

## Version History

- **v1.0.4**: Fixed a real `install.sh` bug — the Copilot hooks merge path (`peon-ping-copilot-setup`, used when `.github/hooks/hooks.json` already exists) contained malformed Python (a dict literal missing its `new_entries = {` assignment, plus an orphaned entry outside it) that threw a `SyntaxError` on every run against an existing hooks file. Confirmed with `python3 -m py_compile` before and after. Also corrected the "Audio in Devcontainers" docs, which claimed no port-forwarding configuration was needed — verified from inside a real devcontainer on native Linux Docker that `host.docker.internal` doesn't resolve there without an explicit `runArgs: ["--add-host=host.docker.internal:host-gateway"]` in the consumer's `devcontainer.json` (a Feature can't add `runArgs` itself). Added concrete manual verification steps.
