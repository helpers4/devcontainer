# Claude Code Development Environment

> Code name: `claude-dev`

Installs the [Claude Code](https://www.anthropic.com/claude-code) IDE extension
across supported editors and persists `~/.claude` (credentials, config, memory)
across every devcontainer rebuild — including GitHub Codespaces — via a Docker
named volume. Optionally installs the `claude` CLI too.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## Example Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {}
  }
}
```

No `initializeCommand` required — Docker creates the volume automatically the
first time it's needed.

With the CLI:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {
      "installCli": true
    }
  }
}
```

## Remote Control: drive this devcontainer from your phone or another computer

With `remoteControl: true`, the devcontainer keeps a Claude Code
[Remote Control](https://code.claude.com/docs/en/remote-control) server running in a background
tmux session. Open [claude.ai/code](https://claude.ai/code) or the Claude app's **Code** tab and
start sessions *in this devcontainer* — its repos, tools, MCP servers, hooks and `~/.claude` —
without a terminal or VS Code window open on it. Code runs here; claude.ai is only the window.

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": {
      "remoteControl": true
    }
  }
}
```

One devcontainer per org (each with its own `~/.claude` volume) gives one server per org; the
name prefixes every session in the list, so `baxyz-…` and `tuxery-…` stay apart.

**First start of a devcontainer:** log in and trust the repo from the Claude extension, as you
would anyway — nothing else. The server waits for both, answers the one-time "Enable Remote
Control?" question itself, and starts; from then on it comes back on every container start.
Log in with a claude.ai account — API keys and `claude setup-token` /
`CLAUDE_CODE_OAUTH_TOKEN` tokens can't use Remote Control. Until then its tmux pane only waits
and checks every 30 s, so nothing registers with Remote Control. The login, the trust and the
confirmation live in `~/.claude.json`, which the feature keeps in the `~/.claude` volume
(`CLAUDE_CONFIG_DIR`), so they survive rebuilds.

**Day to day:** `claude-rc status` shows whether it runs, its name, directory and last output;
`claude-rc stop` / `start` / `restart` do what they say. A stopped server's sessions come back
with `claude-rc start` for about 4 hours.

**Name** (`remoteControlName`), first non-empty of: the option, `$CLAUDE_RC_NAME` (e.g. in
`containerEnv`), [`org-workspace`](../org-workspace)'s `org` option, the owner of the
workspace's `origin` remote, the workspace folder name, the hostname. Set it explicitly when
the automatic name would reveal something you'd rather not see in a session list.

**Directory** (`remoteControlDir`), where sessions start: the workspace folder, i.e. the one
the Claude extension asks you to trust (trust is per directory, so the server must run in a
directory you trusted). With `org-workspace`, the sibling repos in `/workspaces` are reachable
from there but outside the session's starting directory; list them under
`permissions.additionalDirectories` in `~/.claude/settings.json` if sessions should work in them
without asking.

**Spawn mode** (`remoteControlSpawn`): `same-dir` (default) lets every session work in the same
directory — fine across different repos, but two sessions editing the same repo can step on
each other. `worktree` gives each session its own git worktree; it needs the directory to be a
git repository, so it falls back to `same-dir` (with a warning) when the directory isn't one.

**Keep in mind:**

- **Transcripts:** while a session is connected, its transcript is stored on Anthropic's
  servers (execution and files stay here). That's why the option is off by default.
- **Variables that disable it:** `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`,
  `DISABLE_GROWTHBOOK`, an `ANTHROPIC_BASE_URL` other than `api.anthropic.com`, or an API key /
  auth token in the environment. `claude-rc` warns about each at startup.
  `DISABLE_TELEMETRY` / `DO_NOT_TRACK` are fine on recent Claude Code versions.
- **One account:** every session shows up in the claude.ai account the devcontainer is logged
  in with. A devcontainer meant to stay unlinked from your identity needs its own Claude account.
- **Starts with the devcontainer:** the server is started by `postStartCommand`, i.e. whenever
  the devcontainer CLI or VS Code starts the container — not by a bare `docker start`. On an
  always-on host, start devcontainers with `devcontainer up` (e.g. from a systemd unit) so the
  server comes back after a reboot.
- **Flags:** settings for the server's sessions (hooks, permissions, sandboxing) belong in
  `settings.json`, not on the command line — `claude remote-control` refuses most global flags.

## GitHub Codespaces

Works out of the box. A host bind-mount would not: [GitHub Codespaces doesn't
support mounting the local file system](https://code.visualstudio.com/remote/advancedcontainers/add-local-file-mount)
at all, so this feature uses a Docker named volume instead. Each codespace
gets its own volume, populated on your first `/login` there.

The volume name includes `${devcontainerId}`, so it's dedicated to this one devcontainer —
credentials, permissions, hooks, and Claude Code's own per-project memory survive rebuilds of
*this* project, but never bleed into another one. The trade-off: logging in again is needed once
per devcontainer, not once per machine. Earlier versions keyed the volume by `${localEnv:USER}`
instead (one identity shared across every local project) — deliberately dropped, because Claude
Code's own project/memory partitioning keys off the *container-internal* workspace path (e.g.
`/workspaces/<name>`), not a host-unique id: two unrelated projects using the same mount-path
convention would silently share one memory/settings bucket under that model.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user that receives the `~/.claude` symlink. `auto` detects vscode/node/codespace/uid-1000, in that order; set an explicit username to override. |
| `installCli` | boolean | `false` | Install the Claude Code CLI (`claude` command) via the official native installer. |
| `remoteControl` | boolean | `false` | Keep a Remote Control server running in a background tmux session — see [Remote Control](#remote-control-drive-this-devcontainer-from-your-phone-or-another-computer). Implies `installCli`. |
| `remoteControlName` | string | `""` | Name shown in claude.ai/code and prefix of every session name. Empty: automatic (see above). |
| `remoteControlDir` | string | `""` | Directory the server runs in. Empty: the workspace folder (the one you trust in the extension). |
| `remoteControlSpawn` | `same-dir` \| `worktree` | `same-dir` | How the server creates sessions. |
| `remoteControlPermissionMode` | string | `""` | Starting permission mode for the server's sessions (e.g. `acceptEdits`, `plan`). Empty: Claude Code's default. |

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `anthropic.claude-code` |
| Cursor | ✅ | `anthropic.claude-code` (same registry as VS Code) |
| JetBrains (IntelliJ, WebStorm…) | 🔜 | pending `xmlId` confirmation — marketplace page: [plugin/27310](https://plugins.jetbrains.com/plugin/27310) (vendor: Anthropic) |
| Zed | 🔜 | no standard devcontainer customization format yet |

## How it works

1. **Build time** (`install.sh`): generates `/usr/local/share/claude-dev/setup-credentials.sh`
   with the target user's home path baked in.
2. **Mount** (`devcontainer-feature.json → mounts`): mounts the Docker named volume
   `helpers4-claude-credentials-${devcontainerId}` at `/mnt/h4claude` inside the container.
3. **Once, at container creation** (`postCreateCommand`): `setup-credentials.sh` replaces
   `~/.claude` with a symlink to `/mnt/h4claude` — credentials, settings, and Claude Code
   memory all survive rebuilds. Runs exactly once per container instance (a rebuild creates a
   new instance, so it runs again then, but never again on a plain restart of the same one) —
   the volume is already mounted at container creation, before any command runs inside it, so
   there's no need to redo this on every start. Anything another feature wrote into `~/.claude`
   at *image build* time (before this volume existed to write into) is added to the volume
   rather than discarded — see the script's own comments for exactly how.

4. **On every start** (`postStartCommand`): `claude-rc start --lifecycle` — a silent no-op
   unless `remoteControl` is on, in which case it starts the Remote Control loop in a detached
   tmux session named `claude-rc`. It runs after step 3, so the server only ever reads and
   writes the persistent `~/.claude`. It never fails the container start: a missing CLI or tmux
   is a warning. The loop waits for a login, answers the first-run questions by reading the tmux pane ("Enable Remote Control?" → yes; "Trust <dir>?" → no, retried every 30 s until you trust the folder in the extension), then restarts `claude remote-control` whenever it
   exits, backing off up to 5 minutes when it keeps exiting right away.

If `/mnt/h4claude` is not mounted (e.g. a standalone `install.sh` test), the
script warns and exits cleanly — the container starts normally, just without
persistence.

With `installCli: true`, `install.sh` also runs the official native installer
(`curl -fsSL https://claude.ai/install.sh | bash`) as the target user, then
symlinks the resulting binary into `/usr/local/bin/claude` so it's on `PATH`
without depending on that user's shell profile already including
`~/.local/bin`.

## OS and Architecture Support

- **OS:** any (no OS-level installation — pure IDE configuration). `remoteControl` installs
  tmux with apt on Debian/Ubuntu images; elsewhere, have tmux in the image.
- **Architectures:** amd64, arm64

## Version History

- **v1.4.0**: `CLAUDE_CONFIG_DIR` now points at the volume, so `~/.claude.json` (account, trust)
  persists too. Added `remoteControl` (off by default) and its `remoteControlName`,
  `remoteControlDir`, `remoteControlSpawn` and `remoteControlPermissionMode` options: keeps a
  Claude Code Remote Control server running in a background tmux session, started on every
  container start, so this devcontainer can be driven from claude.ai/code or the Claude app.
  New `claude-rc` command (`start`, `login`, `stop`, `restart`, `attach`, `status`). `remoteControl`
  implies `installCli` and installs tmux.
- **v1.3.1**: `setup-credentials.sh` now runs via `postCreateCommand` instead of
  `postStartCommand` — the volume is already mounted by container creation (Docker attaches
  mounts before any command runs inside a container, not later), so there's no need to redo
  the swap on every start; it now happens exactly once per container instance instead. Also
  no longer destructive: anything a feature wrote into `~/.claude` at *image build* time
  (before this volume existed to write into) is added to the volume instead of being silently
  discarded — `cp -rn` only adds what's missing, it never overwrites the volume's own
  accumulated state (real credentials, an actual `settings.json`, memory). Also centralized
  the exclusive-vs-shared volume rationale onto `h4_ensure_volume_writable`'s own comment in
  `helpers4-common`, trimming the near-identical explanation this file (and
  mistral-dev/pnpm-store/playwright-dev) used to restate independently, and cross-references
  peon-ping's dependency on this feature's exact generated-script path. All found during a
  code-review sweep of v1.3.0's coexistence fix with peon-ping — see peon-ping's own v1.3.1
  entry for the other half.
- **v1.3.0**: **Breaking**: the credentials volume is now keyed by `${devcontainerId}` instead
  of `${localEnv:USER}` — each devcontainer gets its own dedicated volume instead of sharing one
  across every local project. You'll need to log in again once per devcontainer instead of once
  per machine. This closes a real cross-project leak: Claude Code partitions memory/sessions by
  its own container-internal workspace path, not by a host-unique id, so two unrelated projects
  using the same mount-path convention (e.g. both mounting their root at `/workspaces/<name>`)
  ended up sharing one memory and permissions bucket under the old, per-user-shared volume. See
  "GitHub Codespaces" above. `h4_ensure_volume_writable` is now called without `--shared`, since
  an exclusive-per-container volume can never have a concurrent writer with a different UID.
- **v1.2.4**: Internal cleanup, no behavior change — dropped dead `_BUILD_ARG_*` fallbacks in
  `install.sh` (`INSTALLCLI`, `USERNAME`). That prefix is only ever set for the legacy
  `internalVersion: "1"` manifest shape, which this feature (and every other one in this
  repo) never declared — the fallback never fired, the plain option env var alone always
  resolved the same value.
- **v1.2.3**: Internal refactor, no behavior change — the shared-volume ownership logic
  (claim on first use, share via `chmod` afterward instead of stealing from another
  project's container) now calls `helpers4-common`'s `h4_ensure_volume_writable --shared`
  instead of carrying its own inline copy.
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
- **v1.0.8**: Fixed `EACCES` errors (e.g. "Failed to retrieve auth status after login",
  `mkdir '.../sessions'` permission denied) on a fresh container: the named volume introduced in
  v1.0.6 is created root-owned by Docker, and nothing chowned it to the container's actual user
  before symlinking `~/.claude` into it. `setup-credentials.sh` now chowns the volume to the
  current user when needed, same pattern `pnpm-store`'s guard script already used.
- **v1.0.7**: Added `installCli` to install the `claude` CLI alongside the extension.
- **v1.0.6**: Switched credential persistence from a host bind-mount to a Docker named volume
  to fix GitHub Codespaces, which doesn't support host bind-mounts at all (#66). **If you're
  upgrading from v1.0.5 or earlier**, this is a breaking change: the new volume starts empty —
  your old host-bound `~/.claude` isn't copied in automatically. Re-authenticate once after
  upgrading, or manually copy your old `~/.claude` content into the new volume (e.g. `docker cp`
  into a throwaway container mounting `helpers4-claude-credentials-${USER}`) if you want to
  keep it.
