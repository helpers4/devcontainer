# Local Development Files Mount (local-mounts)

Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer for seamless development authentication.

## Features

- **Git configuration**: Your `.gitconfig` is available inside the container
- **SSH keys**: Access your SSH keys for Git operations and remote connections
- **GPG keys**: Sign commits with your GPG keys
- **npm authentication**: Use your `.npmrc` for private registry access

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    }
}
```

### With custom username

If your container uses a different username than `node`:

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
| `~/.gitconfig` | `/home/<user>/.gitconfig` | Git user configuration |
| `~/.ssh` | `/home/<user>/.ssh` | SSH keys and config |
| `~/.gnupg` | `/home/<user>/.gnupg` | GPG keys for commit signing |
| `~/.npmrc` | `/home/<user>/.npmrc` | npm registry authentication |

## Prerequisites

Ensure the following files/directories exist on your local machine:

- `~/.gitconfig` - Git configuration
- `~/.ssh` - SSH directory with keys
- `~/.gnupg` - GPG directory (optional, for commit signing)
- `~/.npmrc` - npm configuration (optional, for private registries)

## SSH Agent Forwarding

For best results, ensure SSH agent forwarding is enabled. Add to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
    },
    "mounts": [],
    "initializeCommand": "ssh-add"
}
```

## GPG Commit Signing

To enable GPG commit signing inside the container:

1. Ensure your GPG keys are set up locally
2. Configure Git to use GPG signing:
   ```bash
   git config --global commit.gpgsign true
   git config --global user.signingkey YOUR_KEY_ID
   ```

## Troubleshooting

### SSH keys not working
- Ensure `ssh-agent` is running on your host
- Run `ssh-add` before starting the container
- Check that your SSH keys have correct permissions (600)

### GPG not finding keys
- The `GPG_TTY` environment variable is automatically set
- You may need to run `gpg --list-secret-keys` to initialize

### npm authentication failing
- Verify your `.npmrc` contains valid tokens
- Check that the registry URL matches your private registry
