# Peon Ping — AI Agent Sound Notifications

> Code name: `peon-ping`

Plays your host's [peon-ping](https://peonping.com/) sounds when an AI coding agent in the
devcontainer finishes or needs permission, with hooks for Claude Code, Cursor and OpenAI Codex plus
the [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet)
VS Code sidebar companion. Nothing to configure and nothing downloaded: the sound, the pack and the
volume all come from peon-ping on your **host**.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/peon-ping:1": {}
    }
}
```

No options. Then [start the relay on your host](#start-the-relay-on-your-host) — the only step left
to you.

## How it works

The container has no sound files and no peon-ping install of its own, only one script,
`/usr/local/bin/peon-ping`, with three subcommands:

- **`hook`** — what the agents call. It maps the event to a sound *category* (`session.start`,
  `task.complete`, `input.required`, `task.error`) and asks the relay on your host to play it
  (`GET host.docker.internal:19998/play?category=…`). The host picks a sound from its active pack,
  at its volume, and plays it with its own audio. It also records the event in
  `~/.claude/hooks/peon-ping/.state.json`, which Peon Pet polls. It never blocks the agent and
  exits 0 whether or not the relay is running.
- **`register`** (`postCreateCommand`, once, after `claude-dev` has set up its `~/.claude`) — adds
  the hook to `~/.claude/settings.json` (Claude Code), `~/.cursor/hooks.json` (Cursor) and
  `~/.codex/config.toml` (Codex), always all three. Existing hooks are never overwritten, and a
  file that can't be parsed is left untouched with a warning.
- **`check`** (`postStartCommand`) — makes `host.docker.internal` resolve (below) and tells you if
  the relay isn't running.

Changing pack or volume on your host (`peon packs use …`, `peon volume …`) applies to every
devcontainer immediately, with nothing to keep in sync.

## Start the relay on your host

A Feature can't run anything on your host, so the relay, the one piece that must run there, is
yours to start. On your **host**, with [peon-ping](https://peonping.com/) installed
(`brew install PeonPing/tap/peon-ping` or `curl -fsSL https://peonping.com/install | bash`):

```bash
peon relay --daemon     # start in background
peon relay --status     # check it
peon relay --stop       # stop it
```

Until it runs, the container prints `peon-ping: no sound this session` in its start-up log.
Requires a peon-ping version whose relay supports `/play?category=` (current `main`).

### `host.docker.internal` on native Linux Docker

Docker Desktop (macOS/Windows) resolves `host.docker.internal` by itself; plain Linux Docker
doesn't. `peon-ping check` reads the container's default gateway from `/proc/net/route` — the IP
`--add-host=host.docker.internal:host-gateway` would give — and adds it to `/etc/hosts`. It's a
no-op on Docker Desktop. If it can't write `/etc/hosts`, add this to your `devcontainer.json`
instead:

```jsonc
{ "runArgs": ["--add-host=host.docker.internal:host-gateway"] }
```

On Linux the relay's default bind (`127.0.0.1`) isn't reachable through that gateway IP: start it
with `--bind=<docker bridge gateway>` (`docker network inspect bridge --format '{{(index .IPAM.Config 0).Gateway}}'`)
rather than `0.0.0.0`, so it isn't exposed to your whole LAN.

### GitHub Codespaces and other cloud workspaces

There is no host to reach, so `check` does nothing and the hooks silently no-op.

## Troubleshooting

1. Host: `peon relay --status`.
2. Container: `getent hosts host.docker.internal` prints an IP.
3. Container: `curl -s host.docker.internal:19998/health` prints `OK`. If 2 works but this
   doesn't, the relay is bound to `127.0.0.1` only — see the bind note above.
4. Container: `echo '{"hook_event_name":"Stop"}' | peon-ping hook claude` should play a sound.

## Other agents

GitHub Copilot's VS Code agent hooks read `~/.claude/settings.json`, so it should already be
covered by the Claude Code registration (per Peon Pet's documentation; not confirmed here). Other
agents aren't configured.

## Peon Pet Extension

The [Peon Pet](https://marketplace.visualstudio.com/items?itemName=smcqueen.vscode-peon-pet) VS Code
extension is installed automatically: an animated orc in the sidebar reacting to agent events.
Settings: `peon-pet.size` (`small`, `medium` default, `large`) and `peon-pet.character`.

## Version History

- **v2.0.0**: The container no longer installs peon-ping or any sound pack. Hooks now ask your
  host's relay to play a sound *category* and the host picks pack and volume, so there is nothing
  to mirror or configure. Everything is one script, `peon-ping` (`hook`, `register`, `check`).
  Removed the `packs`, `packsLang`, `volume`, `noRc` and `ideSetup` options (Claude Code, Cursor
  and Codex are always configured), the `peon` CLI and packs inside the container, and the
  `peon-ping-copilot-setup` helper. Breaking: drop those options from your `devcontainer.json`.
  Starting the relay on your host is still a manual step, now reported by `check` at each start
  instead of a one-off install message.
- **v1.3.1**: Installed via `postCreateCommand` instead of at image build time, so it works
  alongside `claude-dev`'s persistent `~/.claude` volume.
- **v1.2.3**: `host.docker.internal` patched into `/etc/hosts` automatically on native Linux Docker.
- **v1.1.0**: Depends on `helpers4-common` instead of an inline copy of its bootstrap.
- **v1.0.6**: Fixed the build on WSL2-backed Docker Desktop hosts.
- **v1.0.5**: Added `packsLang` *(removed in v2.0.0)*.
