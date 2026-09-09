# Bitwarden Secrets Manager CLI

> Code name: `bitwarden-secrets-manager`

This DevContainer feature installs [`bws`](https://github.com/bitwarden/sdk-sm), the official Bitwarden Secrets Manager CLI, directly from Bitwarden's own GitHub releases. It's scoped to non-interactive, machine-account-token access only — no vault login, no unlock flow, no persisted state, no host bind-mounts. Everything it does stays inside the container.

This is deliberately **not** a general Bitwarden feature: it installs `bws` (Secrets Manager) only, not `bw` (the password-vault CLI, which needs an interactive login/session model this feature doesn't address). If you need the vault CLI, look for a dedicated `bw` feature instead.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## When to use this

Use this when a CI-like machine account is the right auth model for your secrets — a
non-interactive token that reads specific Secrets Manager entries, with nothing to unlock and
nothing left behind in the container.

**Alternatives:**
- The `bw` CLI (personal password vault) needs an interactive login/unlock session — a
  different model this feature doesn't address. See the note above if that's what you need.
- Other third-party `bws`/Bitwarden features on `ghcr.io` bind-mount `~/.config/bws` from the
  host to persist login state — this feature avoids that on purpose (see
  [Why no bind mount, no persisted login](#why-no-bind-mount-no-persisted-login) below).
- You could skip this feature entirely and just install `bws` yourself in a `postCreateCommand`
  — this feature's value is the verified download (SHA-256 checked against Bitwarden's own
  published checksums) and the correct `bws-` release-tag filtering, not licensing logic.

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

## Version History

- **v1.2.3**: Documentation only, no functional change — added a "When to use this" section
  with alternatives, matching the equivalent sections other features in this catalog already had.
- **v1.2.2**: Documentation only, no functional change — the previous wording sweep made the
  JSON `description` field far too long, shifting focus away from the feature itself onto the
  self-heal side benefit. Shortened to 5 words and kept generic (no implementation detail like
  "git config"), matching the original's brevity and level of detail.
- **v1.2.1**: Documentation only, no functional change — the self-heal callout above (and the
  JSON `description` field) led with internal jargon ("helpers4's self-heal") instead of the
  actual benefit; reworded to lead with what it does, with the full mechanism staying in
  [`helpers4-common`](../helpers4-common)'s own README.
- **v1.2.0**: Documentation only, no functional change — mentions that `helpers4-common`'s
  automatic git-config self-heal (see above) comes along with this feature.
- **v1.0.0**: Initial release.
