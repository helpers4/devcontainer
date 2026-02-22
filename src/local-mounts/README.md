# Local Development Files Mount (local-mounts)

Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication.

## Features

- **Git configuration**: Your `.gitconfig` is automatically mounted
- **SSH keys**: Access your SSH keys for Git operations and remote connections  
- **SSH agent forwarding**: Automatic `SSH_AUTH_SOCK` configuration
- **GPG keys**: Sign commits with your GPG keys
- **npm authentication**: Your `.npmrc` for private registry access
- **Robust fallback**: Creates empty files if mounts fail, preventing silent failures

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

### With custom username (if not using 'node')

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {
            "username": "vscode"
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `node` | The username in the container to mount files for |

## What Gets Mounted

| Local Path | Container Path | Purpose |
|------------|----------------|---------|
| `~/.gitconfig` | `/home/node/.gitconfig` | Git user configuration |
| `~/.ssh` | `/home/node/.ssh` | SSH keys and config |
| `~/.gnupg` | `/home/node/.gnupg` | GPG keys for commit signing |
| `~/.npmrc` | `/home/node/.npmrc` | npm registry authentication |
| `$SSH_AUTH_SOCK` | `/ssh-agent` | SSH agent forwarding |

## Environment Variables

The feature automatically configures these environment variables:

| Variable | Value | Purpose |
|----------|-------|---------|
| `SSH_AUTH_SOCK` | `/ssh-agent` | SSH agent socket forwarding |
| `GPG_TTY` | `/dev/pts/0` | GPG tty for signing |

## How It Works

1. **Docker mounts** your local configuration files based on the `mounts` specification
2. **Verification script** (`install.sh`) runs inside the container to verify the mounts
3. **Fallback mechanism** creates empty files if mounts fail (prevents silent failures)
4. **Logging** shows what was mounted and what might need attention

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

### SSH keys not working

1. Ensure SSH agent is running on host:
   ```bash
   ssh-add -l  # Should list your keys
   ```

2. Inside container, verify:
   ```bash
   env | grep SSH_AUTH_SOCK
   ssh-add -l  # Should work
   ```

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
2. ✅ If mount failed but file exists locally → Tells you to configure it
3. ✅ If mount failed and file is empty → Creates empty placeholder  
4. ✅ Never crashes or silently fails

The `install.sh` script verifies all mounts and provides clear feedback on what's available.

## SSH Agent Forwarding

The feature automatically configures SSH agent forw forwarding for you. For best results:

1. **Ensure your SSH agent is running** (usually auto on macOS, manual on Linux):
   ```bash
   eval $(ssh-agent -s)
   ssh-add  # Load your keys
   ```

2. **The feature takes care of the rest** - `SSH_AUTH_SOCK` is automatically configured

## Version History

- **v1.0.4**: Fixed `.npmrc` mounting with robust fallback verification
- **v1.0.3**: Initial release
