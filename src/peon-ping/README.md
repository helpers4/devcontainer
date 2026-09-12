# Peon Ping — AI Agent Sound Notifications

> Code name: `peon-ping`

Installs [peon-ping](https://peonping.com/) and the [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet) VS Code extension for game character voice notifications when your AI coding agent finishes or needs permission.

Supports **Claude Code**, **GitHub Copilot**, **Cursor**, **OpenAI Codex**, and [many more IDEs](https://github.com/PeonPing/peon-ping#multi-ide-support).

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Features

- **Sound notifications**: Warcraft, StarCraft, Portal, Zelda and 165+ sound packs
- **Multi-IDE hooks**: Claude Code (built-in), Copilot, Cursor, Codex via adapters
- **Peon Pet extension**: Animated orc sidebar companion reacting to agent events
- **Devcontainer-aware**: Routes audio to host via relay (`host.docker.internal:19998`), automatically patched to resolve on native Linux Docker too — see "Audio in Devcontainers" below
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
| `packsLang` | string | `""` | Restrict pack selection to language(s), e.g. `fr` or `en,fr` — see "Choosing a pack" below |
| `noRc` | boolean | `true` | Skip `.bashrc`/`.zshrc` modifications (recommended for devcontainers) |
| `ideSetup` | string | `vscode` | IDEs to configure: `all` (vscode + cursor + codex), `none`, or CSV (e.g. `vscode,cursor`) |
| `volume` | string | `0.5` | Default volume level (0.0–1.0) |

## Choosing a pack

`packs` already takes a single value (`"glados"`, `"zelda"`, a CSV list, `default`, or `all`), so there's no extra option needed to pick one. The actual friction is finding a name among the ~165 packs in the registry (Warcraft, StarCraft, Red Alert, Portal, Zelda, Dota 2, Helldivers 2, Elder Scrolls, and more) — a static list here would just go stale. Use the tools built for that instead:

```bash
peon packs search <query>       # e.g. `peon packs search zelda`
peon packs use --install <name> # try one immediately, install + switch in one step
```

Or browse with audio previews at [openpeon.com/packs](https://openpeon.com/packs).

Prefer a language over a specific franchise? Set `packsLang` instead of hunting for names:

```jsonc
{
    "features": {
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {
            "packsLang": "fr"
        }
    }
}
```

This matches by each pack's own language metadata (e.g. `peon_fr`, `peasant_fr`), not by
guessing at name patterns — the installer's own `--lang` flag does the filtering. Leaving
`packs` at its default while setting `packsLang` searches the full registry instead of just
the 5 franchise picks below, since those 5 don't all have a matching-language variant.

The `default` bundle is 5 packs:

| Pack | Franchise |
|------|-----------|
| `peon` | Warcraft (Orc Peon) |
| `peasant` | Warcraft (Human Peasant) |
| `sc_kerrigan` | StarCraft (Sarah Kerrigan) |
| `sc_battlecruiser` | StarCraft (Battlecruiser) |
| `glados` | Portal (GLaDOS) |

## Audio in Devcontainers

peon-ping auto-detects devcontainer environments and routes audio to your host machine via a lightweight relay. **You must start the relay on your host:**

```bash
# On your HOST machine — not inside the container
peon relay --daemon
```

The container sends audio requests to `host.docker.internal:19998`.

**On native Linux Docker (not Docker Desktop), `host.docker.internal` doesn't resolve out of the
box** — Docker Desktop (macOS/Windows) injects that DNS entry automatically, plain Linux Docker
doesn't. This feature patches it automatically on every container start (`postStartCommand`):
it reads the container's own default gateway from `/proc/net/route` — the same IP
`--add-host=host.docker.internal:host-gateway` would have resolved to — and adds it to the
container's `/etc/hosts` directly. Nothing to configure; on Docker Desktop it's a no-op, since
`host.docker.internal` already resolves there.

If that patch can't run for some reason (`/etc/hosts` not writable, `sudo` unavailable — check the
container's startup log for a `peon-ping: could not write /etc/hosts` warning), fall back to
adding this to your `devcontainer.json` and rebuilding:

### Coexisting with `claude-dev`

The [`claude-dev`](../claude-dev) feature persists `~/.claude` across rebuilds via a Docker
volume, linked into place once at container creation. A named volume isn't mounted yet during
the *image build* that runs `install.sh` — only once the container is actually created — so
installing straight into `~/.claude` at build time, like the upstream installer does by
default, would land in a spot that isn't the persistent one yet.

peon-ping sidesteps this by not installing at build time at all: the actual install (binary,
packs, Claude Code hooks) runs once via `postCreateCommand`
(`install-claude-hooks.sh`) — after the container, and any mounted volume, already exist.
`installsAfter: claude-dev` (`devcontainer-feature.json`) orders it after claude-dev's own
`postCreateCommand`, so `~/.claude` is already whatever it's going to be for this container by
the time peon-ping installs into it — its own persistent volume if claude-dev is present, an
ordinary directory otherwise. Either way, peon-ping just installs normally, straight into the
real `~/.claude` — no redirection, no relinking, nothing claude-dev-specific. No configuration
needed; this is the same install path whether claude-dev is installed or not.

```jsonc
{
  "runArgs": ["--add-host=host.docker.internal:host-gateway"]
}
```

A Feature can't add `runArgs` itself — it's only read from the consumer's top-level
`devcontainer.json` — which is exactly why the automatic `/etc/hosts` patch above exists.

### Testing the audio path

1. On the **host**: `peon relay --daemon`, then `peon relay --status` to confirm it's listening.
2. Inside the **container**: `getent hosts host.docker.internal` should print an IP (previously
   empty on native Linux Docker before this feature's `postStartCommand` patch runs).
3. Inside the **container**: check the relay port is actually reachable, not just the hostname
   resolving — e.g. `(echo > /dev/tcp/host.docker.internal/19998) 2>&1 && echo reachable || echo unreachable`.
   If this says `unreachable` even after step 2 resolves, the relay on the host is likely bound to
   `127.0.0.1` only (not visible from the container's network) rather than a devcontainer/Feature-side
   problem — check `peon relay --status` output on the host for its bind address.
4. Trigger a real notification (finish an agent turn) and confirm you hear it.

If step 3 fails, that's outside what this feature (or any devcontainer Feature) can fix — it's the
host-side relay's own bind address, controlled by the `peon` CLI itself, not this repo.

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

- **v1.3.1**: Simplified v1.3.0's claude-dev coexistence fix — replaced the redirect-into-a-
  private-directory-then-relink dance (`CLAUDE_CONFIG_DIR`, a stable `claude-home` path,
  `seed-claude-hooks.sh` re-linking hooks/skills and rewriting/merging a settings.json
  fragment) with a plain, unconditional install into the real `~/.claude`, deferred to a new
  `install-claude-hooks.sh` running once via `postCreateCommand` instead of at image build
  time. `postCreateCommand` runs after the container (and any mounted volume) already exists,
  ordered after claude-dev's own via `installsAfter` — by the time it runs, `~/.claude` is
  already whatever it's going to be for this container, so there's nothing left to redirect
  or relink around. peon-ping installs the same way whether claude-dev is present or not — no
  claude-dev-specific code path anymore. See "Coexisting with claude-dev" below.
- **v1.3.0**: Fixed peon-ping never actually working for Claude Code when the `claude-dev`
  feature is also installed — its `postStartCommand` replaces `~/.claude` with a symlink to a
  persistent volume on every start, which silently discarded everything peon-ping had installed
  at build time (including the `peon` binary itself, leaving `command not found`). peon-ping now
  installs into a per-container path claude-dev's swap never touches, and a new
  `seed-claude-hooks.sh` postStartCommand (ordered after claude-dev via `installsAfter`) re-links
  it into the real `~/.claude` and merges its Claude Code hook entries into the real
  `settings.json` — see "Coexisting with claude-dev" above. No behavior change when claude-dev
  isn't installed.
- **v1.2.3**: Removes the manual `runArgs` step on native Linux Docker — a new `postStartCommand`
  (`patch-hosts.sh`) derives the container's default gateway from `/proc/net/route` (the same IP
  `--add-host=host.docker.internal:host-gateway` would have resolved to) and adds it to the
  container's own `/etc/hosts` directly, entirely inside the container. Not a new capability for
  users who'd already added that `runArgs` line — the audio relay worked the same either way; this
  just makes it work without that step. The manual edit stays documented as a fallback for the
  rare case where `/etc/hosts` isn't writable and `sudo` isn't available either.
- **v1.2.2**: Documentation only, no functional change — the previous wording sweep made the
  JSON `description` field far too long, shifting focus away from the feature itself onto the
  self-heal side benefit. Shortened to 5 words and kept generic (no implementation detail like
  "git config"), matching the original's brevity and level of detail.
- **v1.2.1**: Documentation only, no functional change — the self-heal callout above (and the
  JSON `description` field) led with internal jargon ("helpers4's self-heal") instead of the
  actual benefit; reworded to lead with what it does, with the full mechanism staying in
  [`helpers4-common`](../helpers4-common)'s own README.
- **v1.2.0**: Documentation only, no functional change — mentions that `helpers4-common`'s
  automatic git-config self-heal (see above) now comes along with this feature.
- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
- **v1.0.6**: Fixed a build failure on WSL2-backed Docker Desktop hosts: the upstream installer's platform detection misreads a BuildKit `RUN` sandbox as raw WSL (no `/.dockerenv` yet, but the kernel still reports "microsoft") and then hard-requires `powershell.exe`, which isn't available in that sandbox. `install.sh` now sets `REMOTE_CONTAINERS=true` for the installer subshell, forcing correct devcontainer detection.
- **v1.0.5**: Added `packsLang` — restrict pack selection to language(s) instead of naming packs directly, e.g. `packsLang: "fr"`. Passed straight through to the upstream installer's own `--lang` flag, which already understood per-pack language metadata; this just exposes it as a feature option.
- **v1.0.4**: Fixed a Python syntax error in `install.sh`'s Copilot hooks merge path (`peon-ping-copilot-setup`) — it crashed every time it ran against an existing `.github/hooks/hooks.json`. That helper now shares its merge logic with the same `merge_hooks_json` used for Claude Code/Cursor instead of re-deriving it, and an existing `hooks.json` that isn't valid JSON gets backed up to `.bak` instead of silently discarded. Corrected the "Audio in Devcontainers" docs: `host.docker.internal` doesn't resolve on native Linux Docker without `runArgs: ["--add-host=host.docker.internal:host-gateway"]` in the consumer's `devcontainer.json`, which a Feature can't add on its own. Added a "Choosing a pack" section pointing at `peon packs search` and `openpeon.com/packs` instead of adding a preset option — `packs` was already simple enough.
