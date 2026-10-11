<!--
This file is part of helpers4.
Copyright (C) 2025 baxyz
SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Shell History Per Project — Deprecated

> ⚠️ **This feature has been removed.** It was renamed and superseded by [`shell-history`](https://github.com/helpers4/devcontainer/tree/main/src/shell-history).
>
> Existing images that already pulled `ghcr.io/helpers4/devcontainer/shell-history-per-project:1` keep working from their local cache, and v1.2.3 stays on GHCR, but it will get no further updates — **please migrate**.

## Migration

Replace the feature reference in your `devcontainer.json`:

```diff
 "features": {
-    "ghcr.io/helpers4/devcontainer/shell-history-per-project:1": {}
+    "ghcr.io/helpers4/devcontainer/shell-history:1": {}
 }
```

- `maxHistorySize` is unchanged.
- `targetShell` is gone: every shell found in the image (bash, zsh, fish) is configured.
- `historyDirectory` is gone: history lives in a Docker named volume dedicated to this
  devcontainer, mounted at `/mnt/h4history`. If you had added your own mount for
  `/workspaces/.shell-history`, you can remove it.

Your existing history is imported automatically on the first container created with
`shell-history`, if `/workspaces/.shell-history` still holds it.

## Why was it renamed?

The fix changed what the feature does, so it was the moment to give it a plainer name. With VS
Code's default mount, only `/workspaces/<your-repo>` is persisted, not `/workspaces` itself:
`/workspaces/.shell-history` sat in the container's own filesystem and was lost on every
rebuild. It only survived where `/workspaces` is persisted as a whole, like GitHub Codespaces. The
"per project" part of the old name also promised more than it did — every project used the same
file name in the same place. `shell-history` stores history in a volume keyed by the
devcontainer, so each project really gets its own.

## Why is this folder still here?

So that anyone landing on the GitHub URL (`https://github.com/helpers4/devcontainer/tree/main/deprecated/shell-history-per-project`) gets a clear migration pointer instead of a 404. There is intentionally no `devcontainer-feature.json` and no `install.sh` — the feature is not published anymore.

## Last published version

The last `shell-history-per-project` release was **v1.2.3**.
