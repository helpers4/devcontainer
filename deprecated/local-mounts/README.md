<!--
This file is part of helpers4.
Copyright (C) 2025 baxyz
SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Local Mounts — Deprecated

> ⚠️ **This feature has been removed.** It was renamed and superseded by [`dotfiles-sync`](../src/dotfiles-sync/README.md).
>
> Existing images that already pulled `ghcr.io/helpers4/devcontainer/local-mounts:1` keep working from their local cache. New builds referencing this feature will fail to resolve — **you must migrate**.

**Full documentation is preserved on the website:** [helpers4.dev/dev-container/deprecated/local-mounts](https://helpers4.dev/dev-container/deprecated/local-mounts)

## Migration

Replace the feature reference in your `devcontainer.json`:

```diff
 "features": {
-    "ghcr.io/helpers4/devcontainer/local-mounts:1": {}
+    "ghcr.io/helpers4/devcontainer/dotfiles-sync:1": {}
 }
```

The `username` option is identical. Runtime behavior is the same, with extra files supported (cargo, pip, yarn, pnpm, gh CLI prefs, …) and opt-in cloud credentials (AWS profiles, kube config, Docker auth, gh OAuth token).

See the [`dotfiles-sync` README](../src/dotfiles-sync/README.md) for full documentation.

## Why was it renamed?

`local-mounts` only described the mechanism (bind mounts). The new name `dotfiles-sync` describes the **intent** — synchronizing developer dotfiles with a safe merge strategy. The merge logic was rewritten to be safe across local, WSL, macOS, Codespaces, Gitpod, and DevPod.

## Why is this folder still here?

So that anyone landing on the GitHub URL (`https://github.com/helpers4/devcontainer/tree/main/deprecated/local-mounts`) gets a clear migration pointer instead of a 404. There is intentionally no `devcontainer-feature.json` and no `install.sh` — the feature is not published anymore.

## Last published version

The last `local-mounts` release was **v1.0.9**. It is still pullable from GHCR if needed, but no further updates will be published — please migrate to `dotfiles-sync`.
