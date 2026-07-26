---
name: add-devcontainer-feature
description: Scaffold a new DevContainer Feature — manifest, install.sh, README, test — following this repo's conventions
---

Add a new DevContainer Feature to `helpers4/devcontainer`, end to end. Ask the user for the
feature's name and purpose first if it wasn't already specified (kebab-case id, e.g. `foo-dev`).

## 1. Before creating anything

- Check `src/` for an existing feature that already covers this — `ls src/` for the current
  list, don't hardcode or guess it, it drifts. Read `AGENTS.md`'s features table for a
  one-line summary of each.
- Check whether an official/community feature already does this (e.g.
  `ghcr.io/devcontainers/features/*`, `ghcr.io/devcontainers-extra/features/*`). If one exists
  and covers the whole need, prefer depending on it (`installsAfter`) over reimplementing —
  see `angular-dev`, which delegates CLI install to
  `ghcr.io/devcontainers-extra/features/angular-cli` and only adds extensions/settings on top.
  Reimplementing something that already exists needs a real justification (e.g. `github-dev`
  reimplements `gh` CLI install because no known feature bundles the CLI *and* the IDE
  extension together — that bundling is the point of the feature).
- If this is a **dedicated AI-tool feature** (a new IDE assistant, following `claude-dev`/
  `mistral-dev`/`copilot-dev`), it must cover all three: CLI install (if one exists), IDE
  extension, and settings/configuration — not just one or two.

## 2. Files to create

```text
src/<name>/devcontainer-feature.json
src/<name>/install.sh
src/<name>/README.md
test/<name>/test.sh
```

Use `src/git-absorb/` as a reference for a simple binary-install feature, or `src/claude-dev/`
for one that persists host state via a bind-mount + symlink.

### `devcontainer-feature.json`

- Key order: `id` before `version` (some older features have this backwards — don't copy them).
- Start new features at `"version": "1.0.0"`.
- **Must be plain JSON — no `//` comments.** `devcontainers/action` parses it with
  `JSON.parse`, which chokes on JSONC; this broke the release workflow once already (commit
  `4e6e5ee`). Put rationale in the README or `install.sh` instead.
- `installsAfter`: at minimum `["ghcr.io/devcontainers/features/common-utils"]`; add
  `ghcr.io/helpers4/devcontainer/helpers4-common` or other helpers4 features here if this one
  needs them ordered first. Never reference a feature id that isn't in `src/` (or the official
  registry) — it's silently ignored if unresolvable, which hides real typos.
- If this feature needs to persist state from the host (credentials, config), read the
  "Design constraints for features" section in `AGENTS.md` **before** adding a `mounts` entry:
  - A `mounts` source that doesn't exist on the host — file *or* directory — fails the whole
    container at start, unconditionally. No feature script can catch this.
  - A Feature-level `initializeCommand` **does not work** — verified against the
    devcontainers CLI source; it's silently ignored. The only place `initializeCommand` has
    effect is the *consumer's* top-level `devcontainer.json`. So: add the `mounts` +
    `postStartCommand` to the feature as usual, but the required `mkdir -p`/`touch` line goes
    in the feature's own README "Example Usage" as something the consumer must add — see
    `claude-dev`'s or `mistral-dev`'s README for the exact pattern to copy.

### `install.sh`

Pattern (copy the bootstrap block verbatim from `src/helpers4-common/install.sh` or any
existing feature — a CI check in `pr-validation.yml`'s `shellcheck` job fails the build if a
copy drifts from the canonical version):

```bash
#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# <one-line description of what this installs>

set -euo pipefail

# Bootstrap helpers4 shared library. helpers4-common installs it; if running
# standalone (e.g. devcontainer features test), create it inline so the feature
# is self-contained without a GHCR pull.
if [ ! -f /usr/local/share/helpers4/common.sh ]; then
    mkdir -p /usr/local/share/helpers4
    cat > /usr/local/share/helpers4/common.sh << 'H4_COMMON'
# shellcheck shell=bash
h4_detect_user() { ... }   # copy the exact body from an existing feature
h4_resolve_home() { ... }
h4_apt_update() { ... }
h4_ensure_packages() { ... }
H4_COMMON
fi
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.'
    exit 1
fi

h4_detect_user
h4_resolve_home

trap cleanup EXIT
cleanup() { rm -rf /tmp/<name>-* ; }

# ... arch detection (x86_64/aarch64), h4_ensure_packages for apt deps,
#     download/install to /usr/local/bin/ ...
```

Read the actual bootstrap block out of an existing `install.sh` rather than retyping it from
this skill — copy it byte-for-byte so the CI drift check passes.

### `README.md`

Follow the shape of an existing feature's README: title, one-paragraph description, "Example
Usage" (with the `initializeCommand` snippet if this feature mounts host state), an options
table, and a "How it works" section. If the feature evolves after this, add a "Version
History" section (see `dotfiles-sync`'s) documenting what changed and why per bump — future
maintainers (and future agents) rely on it to avoid re-deriving decisions from scratch.

### `test/<name>/test.sh`

```bash
#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing <name> feature..."
# assert the thing the feature installs is present/working; exit 1 on failure
echo "✅ PASS: ..."
```

Keep it about **build-time artifacts** (binary present, file generated, config written) — it
can't exercise `postStartCommand`/mount-dependent behavior, since `devcontainer features test`
doesn't wire up bind mounts from a real host. If the feature declares `mounts`, add a
"Create mount sources for `<name>`" step to `pr-validation.yml`'s `test-features` job (see the
existing steps for `claude-dev`/`mistral-dev`/`dotfiles-sync`) so the test job's own container
build doesn't fail on a missing source.

## 3. Wire it into the repo

In this order — missing any of these breaks CI or leaves the feature undiscoverable:

1. `scopes.json` → add `<name>` (commit scope validation reads this file automatically; PR CI
   fails without it).
2. `.github/workflows/pr-validation.yml` → add `<name>` to the `test-features` job's matrix
   (one entry per base image worth testing against), plus a mount-source step if needed.
3. `.github/workflows/test.yml` → add the same matrix entries (this one runs on push to `main`,
   not per-PR).
4. `AGENTS.md` → add a row to the features table (`| \`<name>\` | 1.0.0 | <one-line description> |`).

## 4. Verify

```bash
devcontainer features test --features <name> .
```

Then, since this is a **new** feature (not yet published), the version-bump-check in
`pr-validation.yml` won't flag it either way — but confirm the manifest still validates as
plain JSON (`jq empty src/<name>/devcontainer-feature.json`) and that `bash -n
src/<name>/install.sh` / `test/<name>/test.sh` come back clean before moving on. Run
`shellcheck -S warning` on both scripts if it's available locally.

## 5. Commit

Only if explicitly asked to commit *this turn* — per `.dev/AGENTS.md`, commit authorization is
per-turn, not a standing grant. When authorized: `feat(<name>): ✨ add <name> feature` as the
scope (matches `scopes.json` once step 3.1 above is done), following the commit format in
`AGENTS.md` (`<type>(<scope>): <emoji> <description>`).
