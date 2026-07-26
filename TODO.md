# TODO — devcontainer feature audit

Plan for two follow-up axes from a feature-suite audit (relevance, host-sync
efficiency, cross-feature coherence). Relevance findings were resolved inline
during the audit; this file tracks the remaining two axes as actionable items.

See `AGENTS.md` → "Design constraints for features" for the invariants this
plan builds on (no direct `mounts` on a host path that might not exist,
out-of-the-box requirement, multi-root workspace support, AI-feature pattern).

## 1. Host sync efficiency

- [x] **`mistral-dev` was non-functional.** Fixed: added `mounts` +
  `postStartCommand` to `devcontainer-feature.json` (v1.0.2). Turns out a
  Feature-level `initializeCommand` (the originally-planned fix) is **silently
  ignored** by the devcontainers CLI — verified by decompiling
  `@devcontainers/cli`'s `devContainersSpecCLI.js`: the lifecycle-merge step
  only collects `initializeCommand` from the top-level `devcontainer.json`,
  never from a Feature. The real fix is a documented, required
  `initializeCommand` line in the consumer's own `devcontainer.json` — added to
  mistral-dev's README "Example Usage", mirroring the pattern `claude-dev`
  already used correctly. See AGENTS.md "Design constraints for features".
- [x] **`claude-dev`'s direct mount of `~/.claude` — checked, no fix needed.**
  Same crash risk is real (confirmed empirically with `docker --mount
  type=bind`: hard failure, both for missing files and missing directories),
  but `claude-dev` already documents the required consumer-side
  `initializeCommand` correctly in its README (this was in fact tried as a
  Feature-level field in v1.0.3 and reverted in a later commit as dead code —
  the removal was correct, not a regression as originally suspected here). No
  change made.
- [x] **`dotfiles-sync`: mandatory file mounts can crash startup.** Fixed by
  documenting a comprehensive `initializeCommand` in the README covering every
  mount source (mandatory *and* opt-in), not just the two originally flagged
  (`~/.npmrc`, `~/.yarnrc.yml`) — same underlying constraint as above (v1.0.7).
- [x] **`dotfiles-sync` username resolution — investigated, not actually a
  divergence.** `claude-dev`/`mistral-dev`'s `username` option turned out to be
  dead code too: their `install.sh` never reads `_BUILD_ARG_USERNAME`, so
  `h4_detect_user`'s auto-detection runs unconditionally and the option has no
  effect either way. `dotfiles-sync`'s simpler `_BUILD_ARG_USERNAME` → getent
  → `"node"` fallback is actually the *more* correct behavior of the three (it's
  the only one where setting the option does anything), and is already
  documented ("Match this to your `remoteUser`"). No change made here — but see
  the new follow-up below, this surfaced a real bug elsewhere.
- [ ] **New: `claude-dev` and `mistral-dev`'s `username` option is dead code.**
  Neither `install.sh` reads `_BUILD_ARG_USERNAME` — `h4_detect_user` runs its
  own auto-detection regardless of what a consumer sets via the `username`
  option. Either wire the option's value into `h4_detect_user`'s precedence
  (consistent with `dotfiles-sync`), or remove the option from both schemas if
  auto-detection is meant to always win. Needs its own pass — touches 2
  features + the shared bootstrap block copied in 8 files, not done in this
  pass to avoid scope creep.

## 2. Cross-feature coherence

- [x] **Shared bootstrap duplication — already covered, no new code needed.**
  `pr-validation.yml`'s `shellcheck` job already has a "Verify bootstrap copies
  match helpers4-common canonical" step that diffs every `install.sh` copy of
  the `h4_detect_user`/`h4_resolve_home`/`h4_ensure_packages` block against
  `helpers4-common`'s canonical version and fails the job on drift. This
  predates this audit; re-verified it actually catches drift (tested locally).
- [x] **License header format drift.** Fixed: `angular-dev`, `git-absorb`,
  `shell-history-per-project` now use the canonical 3-line header (bumped
  1.0.6, 1.0.7, 1.0.7 respectively).
- [x] **Stale reference to a removed feature.** Fixed: `package-auto-install`'s
  `installsAfter` now points at `dotfiles-sync` instead of the removed
  `local-mounts` (v1.0.7).
- [x] **JSON key ordering.** Fixed: `git-absorb` and `shell-history-per-project`
  now put `id` before `version`, matching every other feature (same commits as
  the header fix above).

## 3. Process / tooling

- [x] **Bump feature version on change, once per branch — blocking check.**
  Implemented as a `version-bump-check` job in `pr-validation.yml` (same
  pattern as `conventional-commits`/`shellcheck`: sets `outputs.status`, feeds
  the `pr-comment` summary table). For each feature touched by the PR, diffs
  `version` between the PR's merge-base and HEAD; **fails the job** if it's
  unchanged. No bot commits — a first attempt at auto-bumping-and-pushing was
  dropped as unnecessarily complex (push permissions, fork PRs can't be
  pushed to, bot-commit noise) in favor of a plain blocking check, consistent
  with how `conventional-commits` already works here. The "once per branch"
  behavior falls out of the same diff-against-base logic: once bumped, the
  check passes for every subsequent push to that branch without re-bumping.

## 4. Tooling for contributors

- [x] **`/add-devcontainer-feature` Claude skill.** Added
  `.claude/skills/add-devcontainer-feature/SKILL.md`, mirroring
  `helpers4/typescript`'s `/add-helper` skill: scaffolds a new feature end to
  end following the AGENTS.md checklist (manifest, install.sh, README, test,
  `scopes.json`, workflow matrices, features table) and bakes in the design
  constraints above (mounts, `initializeCommand` placement, JSON-only
  manifests, version bump). Wired into the workspace via
  `.dev/.claude/settings.json`'s `additionalDirectories`, same mechanism
  already used for the typescript repo's skills directory.
