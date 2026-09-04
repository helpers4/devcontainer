# Bitwarden Secrets Manager CLI

This DevContainer feature installs [`bws`](https://github.com/bitwarden/sdk-sm), the official Bitwarden Secrets Manager CLI, directly from Bitwarden's own GitHub releases. It's scoped to non-interactive, machine-account-token access only — no vault login, no unlock flow, no persisted state, no host bind-mounts. Everything it does stays inside the container.

This is deliberately **not** a general Bitwarden feature: it installs `bws` (Secrets Manager) only, not `bw` (the password-vault CLI, which needs an interactive login/session model this feature doesn't address). If you need the vault CLI, look for a dedicated `bw` feature instead.

## Usage

Add this feature to your `devcontainer.json`, and pass your Secrets Manager machine account access token through as an environment variable:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/bitwarden-secrets-manager:1": {}
    },
    "containerEnv": {
        "BWS_ACCESS_TOKEN": "${localEnv:BWS_ACCESS_TOKEN}"
    }
}
```

```bash
bws secret list
bws secret get <secret-id>
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `version` | string | `latest` | Version of `bws` to install (e.g. `"2.1.0"`, `"bws-v2.1.0"`, or `"latest"`) |

## Why no bind mount, no persisted login

`bitwarden/sdk-sm` releases a monorepo of SDKs (`python-vX.Y.Z`, `napi-vX.Y.Z`, `bws-vX.Y.Z`, ...) — this feature filters GitHub releases by the `bws-` tag prefix rather than trusting the repo's `/releases/latest` endpoint, which can (and does) point at an unrelated SDK's release.

Some third-party `bws`/Bitwarden features on `ghcr.io` mount `~/.config/bws` (or similar) from the host into the container to persist login/config state. This feature doesn't, on purpose:

- `bws` auth is a single access token (`BWS_ACCESS_TOKEN`) — there's no interactive login step and no session state worth persisting across rebuilds.
- A host bind-mount whose source directory doesn't exist crashes the whole container at start, and GitHub Codespaces doesn't support host bind-mounts at all. Since there's nothing here that actually needs persisting, adding one would only add that failure mode for no benefit.

Set `BWS_ACCESS_TOKEN` via `containerEnv`/`remoteEnv` (sourced from a host env var, a secret store, or your CI) and `bws` picks it up on every invocation — no setup step required.

## How it works

The binary is downloaded straight from the matching `bws-<arch>-unknown-linux-musl-<version>.zip` GitHub release asset, its SHA-256 checksum verified against Bitwarden's own published checksums file, then extracted to `/usr/local/bin/bws`. The musl build is used (statically linked) so it runs regardless of the base image's libc.

Supported architectures: `x86_64` and `aarch64`/`arm64` (e.g. Oracle Cloud Ampere A1). This feature only ever runs inside the Linux container being built — never on the host — so unlike `bws`'s own multi-OS releases, there's no Darwin/Windows case to detect here.
