# Dotfiles Sync (dotfiles-sync)

Syncs local Git, SSH, GPG, and npm configuration files into the devcontainer. Works on macOS, Linux, Windows (WSL and native), GitHub Codespaces, Gitpod, and DevPod. Uses a **merge strategy** — never overwrites existing values, safe alongside cloud platform native auth and GPG signing.

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

## What Gets Synced

| Local Path | Container Mount (staging) | Final Target | Purpose |
|------------|--------------------------|--------------|---------|
| `~/.gitconfig` | `/tmp/dotfiles-sync/.gitconfig` | `/home/<user>/.gitconfig` | Git user configuration |
| `~/.ssh` | `/tmp/dotfiles-sync/.ssh` | `/home/<user>/.ssh` | SSH keys and config |
| `~/.gnupg` | `/tmp/dotfiles-sync/.gnupg` | `/home/<user>/.gnupg` | GPG keys for commit signing |
| `~/.npmrc` | `/tmp/dotfiles-sync/.npmrc` | `/home/<user>/.npmrc` | npm registry authentication |

## Merge Strategy

Rather than overwriting, the feature **merges** configuration:

| File | Strategy |
|------|----------|
| `.gitconfig` | Applies source keys via `git config` — skips keys already present in target |
| `.npmrc` | Appends `key=value` lines absent from target |
| `.ssh/config` | Appends `Host` blocks not already present |
| `.ssh/known_hosts` | Appends host entries not already present |
| `.ssh` keys | Copies files only if destination does not exist |
| `.gnupg` | Copied on local/WSL; **skipped on cloud environments** (see below) |

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

- **v1.0.0**: Initial release — successor to `local-mounts`. Added multi-environment detection (macOS, Linux, WSL, Codespaces, Gitpod, DevPod), merge strategy for all config files, GPG skip on cloud environments, configurable source paths.
