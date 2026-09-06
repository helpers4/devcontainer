# helpers4-common

Shared bootstrap library for helpers4 DevContainer features. It installs a single
`/usr/local/share/helpers4/common.sh` script providing user detection, home directory
resolution, and apt package helpers — logic that most other helpers4 features need and
used to each carry their own inline copy of.

> **Note**: This is an internal dependency, not a feature you install directly. Other
> helpers4 features pull it in automatically via `dependsOn` — you won't normally add it
> to your `devcontainer.json` yourself.

## What it provides

`common.sh` defines five shell functions, sourced by features that need them:

| Function | Purpose |
|----------|---------|
| `h4_detect_user` | Resolves the target container user (`vscode`, `node`, `codespace`, the first UID 1000 account, or `root`), respecting `USERNAME`/`_REMOTE_USER` and the `auto`/`automatic`/`none` conventions |
| `h4_resolve_home` | Resolves that user's home directory (`/root` or the passwd entry, falling back to `/home/<user>`) |
| `h4_apt_update` | Runs `apt-get update` once, skipped if the apt lists cache is already populated |
| `h4_ensure_packages` | Installs only the packages from its argument list that aren't already present, running `h4_apt_update` first if needed |
| `h4_detect_cloud_env` | Sets `IS_CLOUD_ENV` (`true`/`false`) and `ENV_LABEL` (`GitHub Codespaces`, `Gitpod`, `DevPod`, `WSL`, or `local`) by checking the well-known env vars each platform sets |

## Automatic git-config self-heal

This feature also installs `/usr/local/share/helpers4/git-config-self-heal.sh`, wired up as a
`postAttachCommand` — it runs on every attach, for every helpers4 consumer, with nothing to
configure. No opt-in, because there's nothing here that isn't already broken without it.

**Why:** a client's own automatic `~/.gitconfig` copy (VS Code does this by default) and its SSH
agent forwarding both happen outside any devcontainer Feature's control, verbatim, with no
awareness that a path baked into the host's config might not resolve inside this specific
container — a `credential.helper` shelling out to a snap-managed `gh` at a revision-pinned path
that doesn't exist here, or a `gpg.format=ssh` `user.signingkey` pointing at a public key file
that only ever existed on the host.

**What it fixes, generically** (no per-tool/per-feature knowledge baked in, so it doesn't go
stale as installed tools move around):

- `credential.helper` (including per-URL scopes), `gpg.program`, `gpg.ssh.program`,
  `core.editor` — when the value shells out to an absolute path that doesn't resolve here, it's
  rewritten to the bare command name once a same-named binary is found on `$PATH`. Bare, not a
  freshly-resolved absolute path again: it never goes stale a second time even if the tool moves
  on a future rebuild.
- `user.signingkey` (only when `gpg.format=ssh`) — if the file is missing, tries a same-basename
  file under `~/.ssh`/`~/.gnupg` first (covers a case like `dotfiles-sync` having already placed
  the real file under a different absolute path than the host's), then falls back to recovering
  the public key live from a forwarded `ssh-agent`, matched against `user.email` (`ssh-add -L`
  only — never touches private key material). On GitHub Codespaces, which doesn't forward a
  local `ssh-agent` at all, this can't be derived automatically — the warning points at
  Codespaces secrets and notes that Codespaces signs GPG-format commits natively via its own
  managed proxy, as an alternative.

Anything it can't fix itself is a warning, never a failure — it never blocks the attach.

## Usage (for feature authors)

A feature that needs these helpers depends on this feature instead of inlining its own
copy:

```json
{
    "dependsOn": {
        "ghcr.io/helpers4/devcontainer/helpers4-common:1": {}
    }
}
```

Then, in `install.sh`:

```bash
# shellcheck source=/dev/null
source /usr/local/share/helpers4/common.sh

h4_detect_user
h4_resolve_home
h4_ensure_packages jq curl
```

`helpers4-common` has no options — there is nothing to configure. The git-config self-heal
above is not opt-in either; it runs for every consumer automatically.

## Why a shared feature instead of a copy per feature

Before this feature existed, every helpers4 feature that needed user detection or apt
helpers carried an inline copy of the same ~30 lines of bash. Keeping N copies in sync
by hand doesn't scale, and a fix applied to one copy silently doesn't reach the others.
`helpers4-common` is the single source of truth: fix `h4_ensure_packages` once here, and
every dependent feature picks it up on its next install.

## Version History

- **v1.1.0**: Added `h4_detect_cloud_env` and an automatic `postAttachCommand` git-config
  self-heal (see above) — fixes host-specific paths a client's automatic `.gitconfig` copy or
  SSH agent forwarding leaves broken. Every helpers4 feature now depends on `helpers4-common`
  (the repo-wide migration off each feature's own inlined bootstrap copy), so this runs for
  every consumer automatically, with nothing to add or configure.
- **v1.0.1**: Moved `jq` installation out of this feature and into the individual features
  that actually need it — `helpers4-common` itself no longer installs any packages, only
  the shell functions.
- **v1.0.0**: Initial extraction of the shared bootstrap (user detection, home resolution,
  apt helpers) out of the features that used to inline it.
