# Dotfiles Sync (dotfiles-sync)

Syncs local Git, SSH, GPG, npm, gh, cargo, pip, yarn/pnpm config files into the devcontainer. Optionally syncs cloud credentials (AWS, kube, Docker, gh OAuth token) — opt-in only. Works on macOS, Linux, Windows (WSL and native), GitHub Codespaces, Gitpod, and DevPod. Uses a **merge strategy** for established files and a **copy-if-absent** strategy for new ones — never overwrites existing values, safe alongside cloud platform native auth and GPG signing.

## Usage

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
    }
}
```

That's it. The feature auto-detects the environment and adapts its behavior.

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

## What Gets Synced

### Always synced

| Local Path | Final Target | Strategy | Purpose |
|------------|--------------|----------|---------|
| `~/.gitconfig` | `~/.gitconfig` | Merge via `git config` | Git user configuration |
| `~/.gitignore_global` | `~/.gitignore_global` | Copy-if-absent | Personal global gitignore |
| `~/.config/git/ignore` | `~/.config/git/ignore` | Copy-if-absent | XDG global gitignore |
| `~/.config/git/attributes` | `~/.config/git/attributes` | Copy-if-absent | XDG global gitattributes |
| `~/.config/git/config-*` | `~/.config/git/config-*` | Copy-if-absent | Modular git includes |
| `~/.ssh` | `~/.ssh` | Per-file merge | SSH keys, config, known_hosts |
| `~/.gnupg` | `~/.gnupg` | Copy-if-absent (skipped on cloud) | GPG keys for commit signing |
| `~/.npmrc` | `~/.npmrc` | Merge line-by-line | npm registry auth |
| `~/.yarnrc.yml` | `~/.yarnrc.yml` | Copy-if-absent | yarn registries / settings |
| `~/.config/pnpm/rc` | `~/.config/pnpm/rc` | Copy-if-absent | pnpm settings |
| `~/.config/gh/config.yml` | `~/.config/gh/config.yml` | Copy-if-absent | gh CLI preferences (no token) |
| `~/.cargo/config.toml` | `~/.cargo/config.toml` | Copy-if-absent | Cargo registries / profiles |
| `~/.config/pip/pip.conf` | `~/.config/pip/pip.conf` | Copy-if-absent | pip index URLs |

### Opt-in (sensitive)

| Local Path | Option | Notes |
|------------|--------|-------|
| `~/.aws/config` | `syncAwsConfig` | AWS profiles. `~/.aws/credentials` (long-lived access keys) is **not bind-mounted** and never synced. |
| `~/.kube/config` | `syncKubeConfig` | Kubernetes cluster credentials. Skipped on cloud environments. |
| `~/.docker/config.json` | `syncDockerConfig` | Docker registry auth tokens. Skipped on cloud environments. |

### Never synced

- `~/.config/gh/hosts.yml` — GitHub OAuth tokens are **never** bind-mounted (security). Use the `github-dev` feature with the `GH_TOKEN` env variable, or run `gh auth login` once in the container.
- `~/.aws/credentials` — never bind-mounted, long-lived access keys are too risky to copy into a container.
- Shell rc files (`~/.bashrc`, `~/.zshrc`, `~/.profile`) — would conflict with the container's own shell setup. Use VS Code's native [`dotfiles.repository`](https://code.visualstudio.com/docs/devcontainers/containers#_personalizing-with-dotfile-repositories) for that.

## Merge Strategy

| File | Strategy |
|------|----------|
| `.gitconfig` | Applies source keys via `git config` — skips keys already present in target |
| `.npmrc` | Appends `key=value` lines absent from target |
| `.ssh/config` | Appends `Host` blocks not already present |
| `.ssh/known_hosts` | Appends host entries not already present |
| `.ssh` keys | Copies files only if destination does not exist |
| `.gnupg` | Copied on local/WSL; **skipped on cloud environments** (see below) |
| All other files (gitignore_global, gh/config.yml, cargo, pip, yarn, pnpm, …) | **Copy-if-absent** — never overwrites an existing target |

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

1. Stable socket (`/tmp/dotfiles-sync/.ssh/agent.sock`) if mounted
2. VS Code native forwarding (`$SSH_AUTH_SOCK`)
3. Legacy `/ssh-agent`

## Platform Notes

### macOS / Linux

Works out of the box. `$HOME` is always set and Docker bind mounts resolve correctly.

### WSL (Windows Subsystem for Linux)

Works out of the box. Docker Desktop resolves WSL paths transparently.

### Windows (Docker Desktop, no WSL)

Works in most cases. Docker Desktop automatically translates `C:\Users\<name>` paths from bind mounts into the container. However:

- **`HOME` must be defined** on the host. Most Windows setups have it, but if only `USERPROFILE` is set (no `HOME`), the bind mounts will silently fail — the staging directory `/tmp/dotfiles-sync/` will be empty and no files will be synced. In that case, add `HOME` to your environment variables with the same value as `USERPROFILE`.
- **CRLF line endings** — if `core.autocrlf=true` is set on your Windows Git install, `.gitconfig` and `.npmrc` on disk may contain CRLF. The `.gitconfig` merge uses `git config --list` which normalizes line endings correctly. The `.npmrc` merge reads the file line-by-line via bash which also handles CRLF, but extra `\r` characters may appear in values — if npm auth fails, run `dos2unix ~/.npmrc` inside the container.
- **SSH agent forwarding** — Docker Desktop does not forward the Windows OpenSSH agent socket into containers. SSH auth inside the container will rely on copied key files (`.ssh/id_*`) rather than a live agent. `ssh-add -l` will likely show `Could not open a connection to your authentication agent` — this is expected. Key-based operations (git clone, push) will still work via the copied keys.

### GitHub Codespaces

The feature auto-detects Codespaces via `CODESPACES=true`. Protected keys are preserved, and `.gnupg` is not synced (platform manages GPG signing). See [Cloud environment protection](#cloud-environment-protection) above.

To get signed commits on Codespaces without managing your own key: enable **GitHub Settings → Codespaces → GPG verification**. GitHub will sign commits on your behalf using a GitHub-managed key — they will show as "Verified" on GitHub.com.

### Gitpod

Auto-detected via `GITPOD_WORKSPACE_ID`. Same cloud protection as Codespaces applies.

### DevPod

Auto-detected via `DEVPOD=true` or `DEVPOD_WORKSPACE_ID`. When running on a remote provider (cloud VM), no local files are available — the staging directory will be empty and sync is skipped gracefully. When running locally (Docker), the feature behaves like a standard local devcontainer.

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

- **v1.2.0** — **breaking**: removed `syncGhAuth` option and dropped the `~/.config/gh` directory bind-mount. Only `~/.config/gh/config.yml` is mounted now (single-file). `hosts.yml` (GitHub OAuth token) is never bind-mounted into the container; use the `github-dev` feature with `GH_TOKEN`, or run `gh auth login` inside the container.
- **v1.1.0**: Added many low-risk dotfiles (gitignore_global, git/ignore, git/attributes, yarnrc.yml, pnpm/rc, gh/config.yml, cargo/config.toml, pip/pip.conf) with copy-if-absent strategy. Added 4 opt-in booleans for sensitive files: `syncGhAuth` (gh OAuth token), `syncAwsConfig` (AWS profiles), `syncKubeConfig` (kube credentials), `syncDockerConfig` (Docker registry auth). All opt-ins default to `false` and are skipped on cloud environments. `~/.aws/credentials` is never bind-mounted.
- **v1.0.0**: Initial release — successor to `local-mounts`. Added multi-environment detection (macOS, Linux, WSL, Codespaces, Gitpod, DevPod), merge strategy for all config files, GPG skip on cloud environments, configurable source paths.
