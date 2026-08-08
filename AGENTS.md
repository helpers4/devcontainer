# AGENTS.md — devcontainer

→ [Org-wide rules](https://github.com/helpers4/.dev/blob/main/AGENTS.md): restrictions · commit format · license headers

## This Repository

**Purpose:** DevContainer Features published to `ghcr.io/helpers4/devcontainer/<name>`.

```text
src/<feature>/
├── devcontainer-feature.json  # id, version, options, mounts, postStartCommand, customizations
├── install.sh                 # runs as root at build time
└── README.md
test/<feature>/test.sh
```

**install.sh pattern:** `set -euo pipefail` · root check · `h4_detect_user` / `h4_resolve_home` from `helpers4-common` · apt deps · arch detection (x86_64/aarch64) · install to `/usr/local/bin/` · `trap cleanup EXIT`

**Testing:**

```bash
devcontainer features test --features <name> .
devcontainer features test .
```

**Available features:**

| Feature | Ver | Description |
| ------- | --- | ----------- |
| `helpers4-common` | 1.0.0 | Bootstrap: jq + `common.sh` (user detection, apt helpers) — all features depend on this |
| `essential-dev` | 1.0.2 | Git visualization, editor enhancements, Markdown |
| `github-dev` | 1.0.3 | gh CLI, Copilot Chat, PR/Issues/Actions extensions |
| `copilot-dev` | 1.0.1 | Copilot Chat + AI instructions (commits, PRs, code review) |
| `claude-dev` | 1.0.5 | Claude Code extension + `~/.claude` bind-mount (credentials + memory persist) |
| `mistral-dev` | 1.0.3 | Mistral Vibe extension + `~/.vibe` bind-mount |
| `typescript-dev` | 1.0.5 | TS/JS dev, import management (dependsOn essential-dev) |
| `angular-dev` | 1.0.6 | Angular dev, port 4200 |
| `vite-plus` | 1.0.3 | vp CLI, Oxlint/Oxfmt, Vitest |
| `package-auto-install` | 1.0.7 | Auto-detect and install packages |
| `playwright-dev` | 1.0.0 | Playwright OS deps (Chromium/Firefox/WebKit) + shared browser-binary volume + VS Code extension |
| `pnpm-store` | 1.0.4 | Shared pnpm store via Docker named volume (dependsOn helpers4-common) |
| `auto-header` | — | LGPL-3.0 license headers |
| `git-absorb` | 1.0.7 | git-absorb from GitHub releases |
| `dotfiles-sync` | 1.0.7 | Sync Git/SSH/GPG/npm/gh config from host |
| `peon-ping` | 1.0.3 | AI agent sound notifications |
| `shell-history-per-project` | 1.0.7 | Persistent shell history (zsh/bash/fish) |

**Adding a new feature — checklist:**

1. `src/<name>/devcontainer-feature.json` + `install.sh` + `README.md`
2. `test/<name>/test.sh`
3. `scopes.json` → add the feature name ← **PR CI fails without this** (action reads `scopes.json` automatically)
4. `.github/workflows/pr-validation.yml` + `test.yml` → add to test matrix
5. This `AGENTS.md` features table

**Modifying an existing feature — version bump:**

Any change under `src/<name>/` that touches `install.sh`,
`devcontainer-feature.json`, or `test/<name>/test.sh` must bump that
feature's `version` field (patch by default, minor/major when warranted) —
`release.yml` only tags and publishes a feature whose `version` changed
between the base branch and HEAD, so an unbumped change to something that
actually ships silently never gets published. Bump it **once per branch**:
if the version on the branch already differs from `main`'s, a further commit
on that same branch/PR must *not* bump it again — check the diff against
`main` first, don't bump reflexively on every commit.

A **README-only** change doesn't require a bump — nothing about what ships
in the image changes. It's still worth bumping when the doc fix is
safety-relevant (e.g. a corrected `initializeCommand` requirement, like
`dotfiles-sync` v1.0.8), since `release.yml`'s version-diff gate is also
what triggers the website docs rebuild — an unbumped README fix never
reaches the published site. Judgment call, not enforced either way.

Enforced by the `version-bump-check` job in `pr-validation.yml`: it fails the
PR if a touched feature's `version` is unchanged from `main` *and* something
other than `README.md` changed under that feature's `src/<name>/`. It's a
blocking check only — it never commits a bump on your behalf (deliberately:
no bot commits, no push-permission/fork edge cases, consistent with how
`conventional-commits` already works in this repo). Bump the version
yourself and push again.

**License header (all scripts):**

```bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
```

## Design constraints for features

These are hard requirements, not style preferences — violating them breaks the
container for users, sometimes silently.

- **A `mounts` entry fails the whole container if the host source doesn't
  exist — file *or* directory, no exceptions.** Verified against
  `@devcontainers/cli` directly (decompiled `devContainersSpecCLI.js`):
  `docker run --mount type=bind,...` is used, which errors out
  (`bind source path does not exist`) instead of silently creating anything.
  No feature script can catch this — mounts resolve before `install.sh` /
  `postCreateCommand` / `postStartCommand` ever run.
- **A Feature's own `initializeCommand` cannot fix this — it's silently
  ignored.** Also verified in the CLI source: the lifecycle-command merge
  step only collects `onCreateCommand`, `updateContentCommand`,
  `postCreateCommand`, `postStartCommand`, `postAttachCommand` from each
  Feature (`lv` in the minified bundle) plus `mounts`/`customizations`/etc.
  (`xV`) — `initializeCommand` is *not* in either list. It only has effect in
  the **consumer's own top-level `devcontainer.json`**. This was tried on
  `claude-dev` (v1.0.3, since reverted as dead code) before the real fix
  landed: document a required `initializeCommand` in the feature's README
  Example Usage (see `claude-dev`'s and `mistral-dev`'s READMEs) — a Feature
  cannot inject into the consumer's `devcontainer.json`, so this is the only
  place it can actually run.
- **"Out-of-the-box" for a mount-dependent feature means "one documented
  `initializeCommand` line away," not zero-config.** Given the constraint
  above, don't chase a fully silent fix for a feature with a hard mount
  dependency — document the required line prominently instead. If a feature
  can tolerate a missing/empty source at the file level (many small files,
  like `dotfiles-sync`), prefer staging into `/mnt/h4dotfiles`-style path and
  merging at `postStartCommand` over a hard mount dependency — but note that
  even staged mounts still fail hard if *their* source is missing, so staging
  only helps once the source is guaranteed to exist (see `dotfiles-sync`'s
  own `initializeCommand` requirement for exactly the files it can't avoid
  mounting).
- **`devcontainer-feature.json` must be plain JSON — no `//` comments.**
  `devcontainers/action` parses it with `JSON.parse`, which chokes on JSONC.
  This broke the release workflow once already (see commit `4e6e5ee`). Put
  rationale in the README or a neighboring `.sh` file instead.
- **Must work inside a VS Code multi-root `.code-workspace`** — this repo's own
  devcontainer bundles 6 sibling repos this way (see the root `.dev/CLAUDE.md`
  workspace layout). Treat this as a standard case, not an edge case.
- **Dedicated AI-tool features must cover three things**: CLI install, IDE
  extension, and settings/configuration — see `claude-dev`, `mistral-dev`,
  `copilot-dev`. `github-dev` intentionally reimplements `gh` CLI install
  rather than depending on an upstream feature, because no known existing
  devcontainer feature bundles the CLI *and* the IDE extension together — that
  bundling is the actual reason this feature exists.
