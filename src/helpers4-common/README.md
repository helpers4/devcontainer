# helpers4-common

Shared bootstrap library for helpers4 DevContainer features. It installs a single
`/usr/local/share/helpers4/common.sh` script providing user detection, home directory
resolution, and apt package helpers — logic that most other helpers4 features need and
used to each carry their own inline copy of.

> **Note**: This is an internal dependency, not a feature you install directly. Other
> helpers4 features pull it in automatically via `dependsOn` — you won't normally add it
> to your `devcontainer.json` yourself.

## What it provides

`common.sh` defines four shell functions, sourced by features that need them:

| Function | Purpose |
|----------|---------|
| `h4_detect_user` | Resolves the target container user (`vscode`, `node`, `codespace`, the first UID 1000 account, or `root`), respecting `USERNAME`/`_REMOTE_USER` and the `auto`/`automatic`/`none` conventions |
| `h4_resolve_home` | Resolves that user's home directory (`/root` or the passwd entry, falling back to `/home/<user>`) |
| `h4_apt_update` | Runs `apt-get update` once, skipped if the apt lists cache is already populated |
| `h4_ensure_packages` | Installs only the packages from its argument list that aren't already present, running `h4_apt_update` first if needed |

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

`helpers4-common` has no options — there is nothing to configure.

## Why a shared feature instead of a copy per feature

Before this feature existed, every helpers4 feature that needed user detection or apt
helpers carried an inline copy of the same ~30 lines of bash. Keeping N copies in sync
by hand doesn't scale, and a fix applied to one copy silently doesn't reach the others.
`helpers4-common` is the single source of truth: fix `h4_ensure_packages` once here, and
every dependent feature picks it up on its next install.

## Version History

- **v1.0.1**: Moved `jq` installation out of this feature and into the individual features
  that actually need it — `helpers4-common` itself no longer installs any packages, only
  the shell functions.
- **v1.0.0**: Initial extraction of the shared bootstrap (user detection, home resolution,
  apt helpers) out of the features that used to inline it.
