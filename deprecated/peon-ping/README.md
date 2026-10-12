<!--
This file is part of helpers4.
Copyright (C) 2025 baxyz
SPDX-License-Identifier: LGPL-3.0-or-later
-->

# Peon Ping — Deprecated

> ⚠️ **This feature has been removed.** It will not be replaced.
>
> Existing images that already pulled `ghcr.io/helpers4/devcontainer/peon-ping:1` keep working from their local cache, and v1.3.2 stays on GHCR, but it will get no further updates. New builds that still reference it keep resolving the last published version.

## Migration

Remove the feature from your `devcontainer.json`:

```diff
 "features": {
-    "ghcr.io/helpers4/devcontainer/peon-ping:1": {}
 }
```

If you used the Peon Pet VS Code extension (`smcqueen.vscode-peon-pet`), install it yourself or
drop it from your `customizations.vscode.extensions`.

## Why was it removed?

Playing a host's sounds from inside a container needs a relay running on the host, hooks kept in
sync for several agents (Claude Code, Cursor, Codex), and a setup that survives rebuilds next to
`claude-dev`'s `~/.claude` volume. It never worked reliably enough, and making it so would cost far
more than the feature is worth.

## Why is this folder still here?

So that anyone landing on the GitHub URL (`https://github.com/helpers4/devcontainer/tree/main/deprecated/peon-ping`) gets a clear pointer instead of a 404. There is intentionally no `devcontainer-feature.json` and no `install.sh` — the feature is not published anymore.

## Last published version

The last `peon-ping` release was **v1.3.2**.
