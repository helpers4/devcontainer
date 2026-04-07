# Local Development Files Mount (local-mounts)

Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication, including custom container usernames.

## Features

- **Git configuration**: Your `.gitconfig` is automatically mounted
- **SSH keys**: Access your SSH keys for Git operations and remote connections  
- **SSH agent forwarding**: Runtime detection with fallback chain (stable socket → VS Code native → legacy)
- **GPG keys**: Sign commits with your GPG keys
- **npm authentication**: Your `.npmrc` for private registry access
- **Post-start verification**: Validates mounted content and reports issues

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

That's it! The feature handles everything automatically.

### With custom username (if not using `node`)

```json
{
   "features": {
      "ghcr.io/helpers4/devcontainer/local-mounts:1": {
         "username": "vscode"
      }
   }
}
```

> Make sure this matches your container user (`remoteUser`) to keep paths and ownership consistent.

## Prerequisites

This feature mounts host files/directories into the container. Docker bind mounts are evaluated **before** the feature install script runs.

### Required

- VS Code + Dev Containers extension
- Docker running
- Host paths to mount must exist (for example: `~/.gitconfig`, `~/.ssh`, `~/.gnupg`, `~/.npmrc`)

### SSH agent forwarding

SSH agent forwarding works **out of the box** via VS Code's native mechanism — no extra configuration needed.

For **optimal reliability** (especially across container rebuilds and reconnections), you can optionally configure a stable socket on your host:

**macOS / Linux (zsh)** — add to `~/.zshrc`:

```bash
# Stable SSH agent socket (optional, recommended for devcontainers)
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK")" >/dev/null
    ssh-add 2>/dev/null
fi
```

**Linux (bash)** — add to `~/.bashrc`:

```bash
# Stable SSH agent socket (optional, recommended for devcontainers)
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l >/dev/null 2>&1; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK")" > /dev/null
    ssh-add 2>/dev/null
fi
```

**macOS with Keychain** — add to `~/.zshrc`:

```bash
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
    rm -f "$SSH_AUTH_SOCK"
    eval "$(ssh-agent -a "$SSH_AUTH_SOCK")" >/dev/null
    ssh-add --apple-use-keychain 2>/dev/null
fi
```

After adding the snippet, reload your shell (`source ~/.zshrc`) and verify:

```bash
echo "$SSH_AUTH_SOCK"       # Should show ~/.ssh/agent.sock
ssh-add -l                  # Should list your keys
```

The feature detects the socket at **runtime** with this priority:

1. **Stable socket** (`/tmp/local-mounts/.ssh/agent.sock`) — if exposed on the host
2. **VS Code native forwarding** — automatic, works out of the box
3. **Legacy `/ssh-agent`** — backward compatibility

If one of these host paths does not exist, container startup can fail with a bind-mount error.

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `node` | Container username that receives synchronized local config files |

## What Gets Mounted

| Local Path | Container Mount (staging) | Final Sync Target | Purpose |
|------------|----------------------------|-------------------|---------|
| `~/.gitconfig` | `/tmp/local-mounts/.gitconfig` | `/home/<username>/.gitconfig` | Git user configuration |
| `~/.ssh` | `/tmp/local-mounts/.ssh` | `/home/<username>/.ssh` | SSH keys and config |
| `~/.gnupg` | `/tmp/local-mounts/.gnupg` | `/home/<username>/.gnupg` | GPG keys for commit signing |
| `~/.npmrc` | `/tmp/local-mounts/.npmrc` | `/home/<username>/.npmrc` | npm registry authentication |
| `~/.ssh/agent.sock` | `/tmp/local-mounts/.ssh/agent.sock` | `SSH_AUTH_SOCK` | Stable SSH agent socket forwarding |

## Environment Variables

The feature automatically configures these environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `SSH_AUTH_SOCK` | *(set at runtime via `/etc/profile.d/`)* | SSH agent socket — detected with fallback chain |
| `GPG_TTY` | `/dev/pts/0` | GPG tty for signing |

## How It Works

1. **Docker mounts** your local configuration files based on the `mounts` specification
2. **Verification script** (`install.sh`) runs inside the container to sync from staging mounts into `/home/<username>`
3. **Fallback mechanism** creates placeholders after startup when possible
4. **Logging** shows what was mounted and what might need attention

> Important: bind mounts are resolved before the feature script runs. Missing host sources can block container startup.

## Troubleshooting

### npm authentication failing

**Problem**: npm registry authentication not working inside the container

**Solutions**:
1. **Verify `.npmrc` exists locally**: Run on your host machine:
   ```bash
   ls -la ~/.npmrc
   cat ~/.npmrc  # (check it has tokens)
   ```

2. **Check mount inside container**: Run inside the container:
   ```bash
   ls -la ~/.npmrc
   diff ~/.npmrc /path/on/host/.npmrc  # Should be identical
   ```

3. **If `.npmrc` is empty**:
   - The bind mount likely failed
   - Add authentication tokens to `~/.npmrc` on your host:
     ```bash
     npm config set //registry.example.com/:_authToken=YOUR_TOKEN
     ```

4. **Restart container**: Sometimes a full rebuild helps:
   ```bash
   # In VS Code: Ctrl+Shift+P > Dev Containers: Rebuild Container
   ```

### Git configuration not showing

Check that `.gitconfig` exists on your host:
```bash
# On host
ls -la ~/.gitconfig
git config --global user.name  # Should show your name
```

### SSH agent not forwarded (Permission denied)

If `git fetch` or `ssh -T git@github.com` fails with `Permission denied (publickey)`:

1. Check the socket inside the container:
   ```bash
   echo "$SSH_AUTH_SOCK"
   test -S "$SSH_AUTH_SOCK" && echo "OK" || echo "MISSING"
   ssh-add -l
   ```

2. If the socket is missing, check VS Code's native forwarding on the host:
   ```bash
   # On host
   ssh-add -l           # Must show keys
   echo "$SSH_AUTH_SOCK"  # Must point to a valid socket
   ```

3. Optionally configure a stable socket on the host (see SSH section above).

4. Rebuild the container after fixing the host configuration.

### GPG keys not found

1. Verify GPG is set up locally:
   ```bash
   gpg --list-secret-keys
   ```

2. Inside container, try:
   ```bash
   gpg --list-secret-keys  # Should work if setup locally
   ```

## How the Feature Handles Mount Failures

This feature includes a **robust fallback mechanism**:

1. ✅ If mount succeeded → Uses mounted files
2. ✅ If mounted file content is empty → warns with troubleshooting hints
3. ✅ If startup succeeded but target path is missing → creates placeholder where possible
4. ⚠️ If host bind source is missing before startup → Docker can fail before script execution

The `install.sh` script verifies all mounts and provides clear feedback on what's available.

## Version History

- **v1.0.7**: Replaced static `containerEnv` SSH_AUTH_SOCK with runtime detection via `/etc/profile.d/` — preserves VS Code native forwarding as fallback
- **v1.0.6**: Added `username` option with mount staging (`/tmp/local-mounts`) and sync to `/home/<username>`
- **v1.0.5**: Removed fragile direct `$SSH_AUTH_SOCK` bind mount and switched to stable `~/.ssh/agent.sock` strategy
- **v1.0.4**: Fixed `.npmrc` mounting with robust fallback verification
- **v1.0.3**: Initial release
