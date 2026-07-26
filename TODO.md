# TODO — devcontainer feature audit

Plan for two follow-up axes from a feature-suite audit (relevance, host-sync
efficiency, cross-feature coherence). Relevance findings were resolved inline
during the audit; this file tracks the remaining two axes as actionable items.

See `AGENTS.md` → "Design constraints for features" for the invariants this
plan builds on (no direct `mounts` on a host path that might not exist,
out-of-the-box requirement, multi-root workspace support, AI-feature pattern).

## 1. Host sync efficiency

- [ ] **`mistral-dev` is non-functional.** `devcontainer-feature.json` has
  neither `mounts` nor `postStartCommand` — `setup-credentials.sh` is generated
  at build time but never run, and even if it were, `/mnt/h4vibe` would never
  exist. **Do not fix by copying `claude-dev`'s direct-mount pattern** — same
  crash risk applies (see next item). Needs the `dotfiles-sync`-style staging
  pattern instead, adapted for a single directory instead of many small files.
- [ ] **`claude-dev`'s direct mount of `~/.claude` may have the same
  fragility.** If a missing host directory source really does fail the mount
  hard (per the constraint above), a first-time user with no `~/.claude` yet
  fails at container build. Confirm the actual failure mode, and if it fails,
  give `claude-dev` the same staging fix as `mistral-dev`.
- [ ] **`dotfiles-sync`: undocumented risk on two mandatory file mounts.**
  `~/.npmrc` and `~/.yarnrc.yml` are bind-mounted unconditionally even though
  they're "frequently absent" files — the same category the v1.0.4 changelog
  removed others for (`~/.gitignore_global`, `~/.cargo/config.toml`, …). Either
  drop them from the mandatory `mounts` list, or document the same "create it,
  even empty, to unblock startup" caveat already given for the opt-in section.
- [ ] **`dotfiles-sync` username resolution diverges from the rest of the
  suite.** It doesn't use `h4_detect_user` (identical in 8 other features) —
  falls back hard to `"node"` instead of auto-detecting vscode/codespace/
  uid-1000. Align it, or document why it's deliberately different.

## 2. Cross-feature coherence

- [ ] **Shared bootstrap duplication.** The `h4_detect_user` /
  `h4_resolve_home` / `h4_ensure_packages` block is byte-identical across 8
  `install.sh` files (verified via md5). Fine as a deliberate "self-contained,
  no GHCR pull" fallback, but nothing keeps the 8 copies in sync when the block
  changes. Decide: document the manual-sync obligation explicitly, or add a CI
  check that diffs every copy against `helpers4-common`'s canonical version.
- [ ] **License header format drift.** `angular-dev`, `git-absorb`,
  `shell-history-per-project` still use the pre-AGENTS.md header format (prose
  license line, no SPDX identifier). Update to the canonical 3-line header.
- [ ] **Stale reference to a removed feature.** `package-auto-install`'s
  `installsAfter` still lists `ghcr.io/helpers4/devcontainer/local-mounts`,
  which no longer resolves (renamed to `dotfiles-sync`). Harmless
  (`installsAfter` silently ignores unresolvable IDs) but should be updated.
- [ ] **JSON key ordering.** `git-absorb` and `shell-history-per-project` put
  `version` before `id`; every other feature does the opposite. Cosmetic —
  align for consistency.

## 3. Process / tooling

- [ ] **Auto-bump feature version on change, once per branch.** `release.yml`
  only tags/publishes a feature whose `version` changed between the base
  branch and HEAD (see AGENTS.md "Modifying an existing feature — version
  bump"), so today an unbumped change silently never ships — this is a manual
  habit, not enforced. Add a `pr-validation.yml` step (or a separate workflow)
  that, for each `src/<feature>/` touched by the PR:
  - reads `version` for that feature on `main` vs on the PR branch HEAD,
  - if unchanged → bump patch and push a commit to the PR branch,
  - if already different → do nothing (this *is* the "once per branch" rule:
    no extra branch-local state needed, the diff-against-`main` check is
    naturally idempotent across repeated pushes to the same branch).
  Decide bump granularity policy (always patch vs. letting a PR label pick
  minor/major) before implementing.
