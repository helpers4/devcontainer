# Dotfiles Sync (dotfiles-sync)

Syncs local Git, SSH, GPG, npm, and yarn config files into the devcontainer. Optionally syncs cloud credentials (AWS, kube, Docker) and SSH private key files — opt-in only. Works on macOS, Linux, Windows (WSL and native), GitHub Codespaces, Gitpod, and DevPod. Uses a **merge strategy** for established files and a **copy-if-absent** strategy for new ones — never overwrites existing values, safe alongside cloud platform native auth and GPG signing.

> **Recommended**: if you use this feature, disable VS Code's own automatic `.gitconfig` copy (`"dev.containers.copyGitConfig": false`, a client-side VS Code setting — not something a `devcontainer.json` can control). VS Code's copy runs earlier and writes every key verbatim; this feature's merge only fills in whatever's still absent by the time it runs, so with both active, VS Code's raw copy silently wins for every key it touched and this feature's smarter merge does nothing for those. Either way, [`helpers4-common`](../helpers4-common)'s automatic git-config self-heal (every helpers4 consumer gets it, unconditionally) repairs host-specific paths left over by whichever one actually wrote them.

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
    }
}
```

The feature auto-detects the environment and adapts its behavior. **Add
`initializeCommand`** so every bind-mount source is guaranteed to exist before
Docker resolves the mounts — without it, a container can fail to start on a
machine that's simply never created one of these files (see "Operational
note" below):

```json
{
    "initializeCommand": "mkdir -p ~/.ssh ~/.gnupg ~/.config/git ~/.aws ~/.kube ~/.docker && touch ~/.gitconfig ~/.npmrc ~/.yarnrc.yml ~/.aws/config ~/.kube/config ~/.docker/config.json",
    "features": {
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
    }
}
```

This can't be baked into the feature itself — a Feature's own
`initializeCommand` field is silently ignored by the devcontainers CLI, only
the consumer's top-level `devcontainer.json` is honored for it (see AGENTS.md
"Design constraints for features"). `mkdir -p`/`touch` on paths that already
exist are no-ops, so this is always safe to add.

### With custom username

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {
            "username": "vscode"
        }
    }
}
```

> Match this to your `remoteUser` in `devcontainer.json`.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `node` | Container username that receives synchronized config files |
| `syncAwsConfig` | boolean | `false` | Sync `~/.aws/config` (profiles only — `~/.aws/credentials` is **never** synced). |
| `syncKubeConfig` | boolean | `false` | Sync `~/.kube/config` (cluster credentials and tokens). Skipped on cloud environments. |
| `syncDockerConfig` | boolean | `false` | Sync `~/.docker/config.json` (registry auth tokens). Skipped on cloud environments. |
| `syncSshKeys` | boolean | `false` | Sync SSH private/public key files themselves (`~/.ssh/id_*`). `~/.ssh/config` and `known_hosts` always sync regardless — see [SSH key files](#ssh-key-files-opt-in) below. |

## What Gets Synced

### Always synced

| Local Path | Final Target | Strategy | Purpose |
|------------|--------------|----------|---------|
| `~/.gitconfig` | `~/.gitconfig` | Merge via `git config` | Git user configuration |
| `~/.config/git/ignore` | `~/.config/git/ignore` | Copy-if-absent | XDG global gitignore |
| `~/.config/git/attributes` | `~/.config/git/attributes` | Copy-if-absent | XDG global gitattributes |
| `~/.config/git/config-*` | `~/.config/git/config-*` | Copy-if-absent | Modular git includes |
| `~/.ssh/config` | `~/.ssh/config` | Merge `Host` blocks | SSH host aliases — not provided by agent forwarding |
| `~/.ssh/known_hosts` | `~/.ssh/known_hosts` | Merge line-by-line | Trusted host fingerprints — not provided by agent forwarding |
| `~/.gnupg` | `~/.gnupg` | Copy-if-absent (skipped on cloud) | GPG keys for commit signing |
| `~/.npmrc` | `~/.npmrc` | Merge line-by-line | npm registry auth |
| `~/.yarnrc.yml` | `~/.yarnrc.yml` | Copy-if-absent | yarn registries / settings |

### Opt-in (sensitive)

**Operational note — bind-mounts are unconditional:** DevContainer Feature `mounts` cannot be gated on option values. The files below are always bind-mounted into `/mnt/h4dotfiles` at container start, regardless of the option value. The option only controls whether `sync-files.sh` copies the staged file into `$HOME`. Consequences:

- **Startup failure risk** — Docker file bind-mounts fail hard if the source path does not exist on the host. If you don't have `~/.aws/config`, `~/.kube/config`, or `~/.docker/config.json`, the container will fail to start even if the corresponding option is `false`. The `initializeCommand` in "Usage" above pre-creates all of them (empty file, `touch`) so this can't happen — that's the supported fix, not creating the file by hand once and hoping it survives.
- **Data visible in staging** — even when the option is `false`, the host file is accessible inside the container at `/mnt/h4dotfiles/<path>`. Nothing reads that path unless the option is enabled, but if your threat model requires full isolation, do not use the feature for that credential.

The same startup-failure risk applies to the "always synced" files above
(`~/.npmrc`, `~/.yarnrc.yml` in particular are frequently absent on a fresh
machine) — the `initializeCommand` in "Usage" covers those too.

| Local Path | Option | Notes |
|------------|--------|-------|
| `~/.aws/config` | `syncAwsConfig` | AWS profiles. `~/.aws/credentials` (long-lived access keys) is **not bind-mounted** and never synced. |
| `~/.kube/config` | `syncKubeConfig` | Kubernetes cluster credentials. Skipped on cloud environments. |
| `~/.docker/config.json` | `syncDockerConfig` | Docker registry auth tokens. Skipped on cloud environments. |
| `~/.ssh/id_*` (private + public key files) | `syncSshKeys` | See [SSH key files](#ssh-key-files-opt-in) below. |

### SSH key files (opt-in)

Off by default, on purpose. The client's own forwarded `ssh-agent` already covers normal SSH
authentication (`git clone`/`push` over SSH, `ssh user@host`) with **no local key file needed at
all** — the agent supplies public-key identities and performs signing challenges live, over the
socket, without a file ever touching the container's disk. Copying the actual key files here
would put private key material on the container's filesystem for something that already works
without it.

The one thing agent forwarding *doesn't* cover is `user.signingkey` for `gpg.format=ssh` commit
signing — `ssh-keygen -Y sign` (what git delegates SSH-format signing to) needs an actual public
key **file** path, not just "ask the agent live". You don't need `syncSshKeys` for that either:
[`helpers4-common`](../helpers4-common)'s automatic self-heal derives that one file from the
forwarded agent (matched against `user.email`) on its own, with nothing to enable.

Turn `syncSshKeys` on only if you have a specific reason to want the actual key files present
inside the container (a tool that reads a private key file directly rather than going through
an agent, for instance).

### Never synced

- `~/.aws/credentials` — never bind-mounted, long-lived access keys are too risky to copy into a container.
- Shell rc files (`~/.bashrc`, `~/.zshrc`, `~/.profile`) — would conflict with the container's own shell setup. Use VS Code's native [`dotfiles.repository`](https://code.visualstudio.com/docs/devcontainers/containers#_personalizing-with-dotfile-repositories) for that.

## GitHub authentication

`gh` CLI authentication is not managed by this feature. Pick whichever fits your workflow:

1. **`github-dev` feature + `GH_TOKEN`** (recommended for fine-grained scope):

   ```jsonc
   {
     "features": {
       "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {},
       "ghcr.io/helpers4/devcontainer/github-dev:1": {}
     },
     "containerEnv": {
       "GH_TOKEN": "${localEnv:GH_TOKEN}"
     }
   }
   ```

2. **`gh auth login` inside the container** — token stays in the container only.

## Merge Strategy

| File | Strategy |
|------|----------|
| `.gitconfig` | Applies source keys via `git config` — skips keys already present in target |
| `.npmrc` | Appends `key=value` lines absent from target |
| `.ssh/config` | Appends `Host` blocks not already present |
| `.ssh/known_hosts` | Appends host entries not already present |
| `.ssh` keys | Copies files only if destination does not exist |
| `.gnupg` | Copied on local/WSL; **skipped on cloud environments** (see below) |
| All other files (git/ignore, git/attributes, yarnrc.yml, …) | **Copy-if-absent** — never overwrites an existing target |

### Host-specific paths in `.gitconfig`

The host's `.gitconfig` can reference files or binaries by absolute host path (`user.signingkey`
for SSH-based commit signing; `credential.helper`, `gpg.program` shelling out to a host-specific
tool location). Those paths are frequently meaningless inside the container — a tool installed
at a different path here, or a file that was never copied in.

This feature's own merge (above) does **not** rewrite or verify any of that anymore — as of
v1.1.0 that responsibility moved to [`helpers4-common`](../helpers4-common)'s automatic
`postAttachCommand` self-heal, which actively repairs it (not just warns) on every attach,
whether or not this feature is even in use, and whether the broken value came from this
feature's own merge or from a client's own automatic `.gitconfig` copy. See that feature's
README for exactly what it fixes.

### Cloud environment protection

On **GitHub Codespaces**, **Gitpod**, and **DevPod**, the platform manages git authentication and GPG signing. The following `.gitconfig` keys are **never overwritten** if already set by the platform:

| Key | Reason |
|-----|--------|
| `credential.helper` | Platform injects its own token-based credential helper |
| `user.name` | Set from your platform profile |
| `user.email` | Set from your platform profile |
| `user.signingkey` | Platform uses its own signing key |
| `gpg.program` | Codespaces injects `/.codespaces/bin/gh-gpgsign` — overwriting it breaks signing |
| `gpg.format` | Managed by platform |
| `commit.gpgsign` | Managed by platform |
| `tag.gpgsign` | Managed by platform |

### GPG signing on cloud environments

`.gnupg` is **not synced** on cloud environments because:

- **GitHub Codespaces**: uses `/.codespaces/bin/gh-gpgsign`, a GitHub-managed proxy. Commits are signed with a GitHub key and show as "Verified" on GitHub.com. To enable it: **GitHub Settings → Codespaces → GPG verification**.
- **Gitpod**: manages its own signing mechanism.
- **DevPod**: when remote, no local GPG agent is available.

Importing local GPG keys into a cloud environment would conflict with the platform proxy and break signing. On **local and WSL**, `.gnupg` is synced normally.

## SSH Agent Forwarding

SSH agent forwarding works out of the box via VS Code native mechanism.

For **optimal reliability** across container rebuilds, configure a stable socket on your host:

**macOS / Linux (zsh / bash)** — add to your shell rc:

```bash
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK")" >/dev/null
    ssh-add 2>/dev/null
fi
```

**macOS with Keychain**:

```bash
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK")" >/dev/null
    ssh-add --apple-use-keychain 2>/dev/null
fi
```

Socket detection priority at runtime:

1. Stable socket (`/mnt/h4dotfiles/.ssh/agent.sock`) if mounted
2. VS Code native forwarding (`$SSH_AUTH_SOCK`)
3. Legacy `/ssh-agent`

## Platform Notes

### macOS / Linux

Works out of the box. `$HOME` is always set and Docker bind mounts resolve correctly.

### WSL (Windows Subsystem for Linux)

Works out of the box. Docker Desktop resolves WSL paths transparently.

### Windows (Docker Desktop, no WSL)

Works in most cases. Docker Desktop automatically translates `C:\Users\<name>` paths from bind mounts into the container. However:

- **`HOME` must be defined** on the host. Most Windows setups have it, but if only `USERPROFILE` is set (no `HOME`), the bind mounts will silently fail — the staging directory `/mnt/h4dotfiles/` will be empty and no files will be synced. In that case, add `HOME` to your environment variables with the same value as `USERPROFILE`.
- **CRLF line endings** — if `core.autocrlf=true` is set on your Windows Git install, `.gitconfig` and `.npmrc` on disk may contain CRLF. The `.gitconfig` merge uses `git config --list` which normalizes line endings correctly. The `.npmrc` merge reads the file line-by-line via bash which also handles CRLF, but extra `\r` characters may appear in values — if npm auth fails, run `dos2unix ~/.npmrc` inside the container.
- **SSH agent forwarding** — Docker Desktop does not forward the Windows OpenSSH agent socket into containers. SSH auth inside the container will rely on copied key files (`.ssh/id_*`) rather than a live agent. `ssh-add -l` will likely show `Could not open a connection to your authentication agent` — this is expected. Key-based operations (git clone, push) will still work via the copied keys.

### GitHub Codespaces

This feature needs the same `initializeCommand` here as anywhere else, and has nothing to sync unless you've set up Codespaces' own dotfiles personalization separately.

`${localEnv:HOME}` — the source of every bind mount this feature declares — resolves against the **Codespaces VM that GitHub provisions for you**, not your actual laptop. There is no path from a codespace back to your local machine's filesystem; Codespaces never has access to it. Two consequences:

- **The same startup risk applies here.** A fresh codespace VM's home directory has no reason to already contain `.gitconfig`, `.ssh`, `.gnupg`, `.npmrc`, `.yarnrc.yml`, etc. If any of those are missing, the bind mount fails and the codespace won't build. Add the same `initializeCommand` from the "Usage" section — it runs on the codespace VM at creation time, same as it would on your laptop.
- **Even once it builds, there's nothing meaningful to sync** unless something else populated the codespace VM's home first. If you use GitHub's own, separate personalization mechanism — a **[dotfiles repository](https://docs.github.com/en/codespaces/setting-your-user-preferences/personalizing-github-codespaces-for-your-account#dotfiles)** configured under your GitHub account settings — GitHub clones it into the codespace VM *before* this feature's mounts resolve, and this feature will then merge whatever that repository placed at `~/.gitconfig`, `~/.ssh`, etc., same as it would on a real local machine. Without that, every mount source exists (thanks to `initializeCommand`) but is empty, and every file this feature "syncs" is just an empty placeholder.

What still applies as before: the feature auto-detects Codespaces via `CODESPACES=true`, protected keys are preserved, and `.gnupg` is not synced (platform manages GPG signing) — see [Cloud environment protection](#cloud-environment-protection) above. To get signed commits without managing your own key: enable **GitHub Settings → Codespaces → GPG verification**; GitHub signs commits on your behalf and they show as "Verified" on GitHub.com.

There's an open upstream proposal for `mounts` entries to support an `optional: true` flag (`devcontainers/spec#132`) that would let a feature itself guarantee this instead of pushing the requirement onto every consumer's `devcontainer.json` — not merged as of this writing, and several other projects hit the exact same `.aws`/`.kube`-style problem in that thread using the same `initializeCommand` workaround documented here.

### Gitpod

Auto-detected via `GITPOD_WORKSPACE_ID`. Same cloud protection as Codespaces applies, and the same reasoning above holds: `${localEnv:HOME}` resolves against the Gitpod workspace, not your local machine, so the same `initializeCommand` requirement and "nothing to sync without separate personalization" caveat apply.

### DevPod

Auto-detected via `DEVPOD=true` or `DEVPOD_WORKSPACE_ID`. When running on a remote provider (cloud VM), the same `initializeCommand` requirement applies as above; without it, or without something else populating the remote host's home directory first, the staging directory will be empty and sync is skipped gracefully rather than syncing anything meaningful. When running locally (Docker), the feature behaves like a standard local devcontainer.

## How It Works

1. **Build time** (`install.sh`): Creates directory structure and installs sync scripts
2. **Container start** (`postStartCommand`): Merges files from staging to user home
3. **Shell startup** (`/etc/profile.d/`): SSH agent detection + one-time sync fallback

## Troubleshooting

### npm auth failing

```bash
# On host
cat ~/.npmrc

# In container
cat ~/.npmrc
```

If empty: rebuild the container after verifying the host file exists.

### Git config not appearing

```bash
# In container
git config --list --show-origin
```

### SSH permission denied

```bash
# In container
echo "$SSH_AUTH_SOCK"
test -S "$SSH_AUTH_SOCK" && echo "OK" || echo "MISSING"
ssh-add -l
```

---

> **Migrating from `local-mounts`?** This feature is the successor to `local-mounts`. Replace `ghcr.io/helpers4/devcontainer/local-mounts:1` with `ghcr.io/helpers4/devcontainer/dotfiles-sync:1` — options and behavior are identical.

## Version History

- **v1.1.0**: SSH private/public key file copying is now opt-in (`syncSshKeys`, default `false`)
  — `~/.ssh/config` and `known_hosts` still always sync (agent forwarding doesn't provide
  either), but actual key files no longer land on the container's filesystem unless explicitly
  requested; normal SSH auth already works through the forwarded agent with no local file
  needed. Also removed this feature's own `.gitconfig` path-rewriting and verification
  (`path-keys.sh`) — that responsibility moved to `helpers4-common`'s new automatic
  `postAttachCommand` self-heal, which fixes it for every consumer regardless of whether this
  feature is even in use, and now depends on `helpers4-common` accordingly.
- **v1.0.8**: Corrected the Codespaces/Gitpod/DevPod notes — the `initializeCommand` requirement from "Usage" applies to cloud environments too, since `${localEnv:HOME}` resolves against the cloud VM, not your laptop. Even with it, there's nothing to sync without a Codespaces dotfiles repository configured separately. Previously these sections only covered what gets merged, not whether the mount succeeds. Docs only, no behavior change.
- **v1.0.7**: Documented the required `initializeCommand` in "Usage" (pre-creates every bind-mount source, mandatory and opt-in) so a container can't fail to start on a machine missing one of these files — a Feature's own `initializeCommand` is silently ignored by the devcontainers CLI, so this has to live in the consumer's `devcontainer.json`, not the feature. No behavior change to `sync-files.sh`.
- **v1.0.4**: Removed bind-mounts for files that are frequently absent on host machines and have little value inside a devcontainer: `~/.gitignore_global` (redundant with `~/.config/git/` directory mount), `~/.config/pnpm/rc` (pnpm store-dir is counter-productive in a container), `~/.config/gh/config.yml` and `~/.config/gh/hosts.yml` (gh CLI auth managed separately), `~/.cargo/config.toml` (cargo not relevant in most containers), `~/.config/pip/pip.conf` (too environment-specific). Docker file bind-mounts fail hard if the source path doesn't exist on the host, which was causing containers to fail to start. The `syncGhAuth` option is removed.
- **v1.0.3**: Fixed incompatibility with `docker-in-docker` feature — staging directory moved from `/tmp/dotfiles-sync/` to `/mnt/h4dotfiles/` to avoid being hidden by the tmpfs that `docker-in-docker` mounts on `/tmp` at container start.
- **v1.0.2**: Added `syncGhAuth` opt-in to copy `~/.config/gh/hosts.yml` (GitHub OAuth token used by `gh` CLI) into `$HOME`. Default `false`, skipped on cloud environments. The file is bind-mounted into `/tmp/dotfiles-sync/` regardless (Feature `mounts` cannot be conditional) but only copied to `$HOME` when the option is enabled. For fine-grained PATs prefer the `github-dev` feature with `GH_TOKEN`.
- **v1.0.1**: Stop bind-mounting the `~/.config/gh` directory. Only `~/.config/gh/config.yml` (CLI preferences) is mounted. Added 3 opt-in booleans for sensitive files: `syncAwsConfig`, `syncKubeConfig`, `syncDockerConfig` — all default `false` and skipped on cloud environments. Added low-risk dotfiles (gitignore_global, git/ignore, git/attributes, yarnrc.yml, pnpm/rc, cargo/config.toml, pip/pip.conf) with copy-if-absent strategy. `~/.aws/credentials` is never bind-mounted.
- **v1.0.0**: Initial release — successor to `local-mounts`. Multi-environment detection (macOS, Linux, WSL, Codespaces, Gitpod, DevPod), merge strategy for all config files, GPG skip on cloud environments, configurable source paths.
