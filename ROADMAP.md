# Roadmap / Ideas — devcontainer

Backlog of future work — not an active plan. Items here are known gaps or open questions,
not yet scoped or scheduled.

- [ ] **release.yml: tag pushes still get rejected when their ref history touches a workflow
  file.** The actual GitHub restriction here needs a token with the classic PAT `workflow`
  OAuth scope, or a GitHub App installation token (via `actions/create-github-app-token`) —
  there's no `permissions:` YAML key for this on the default `GITHUB_TOKEN` (confirmed against
  GitHub's own workflow schema; a `workflows: write` permission block doesn't exist and just
  makes the whole file invalid — hit that for real, reverted it). Needs a secret provisioned
  before this can be fixed properly.

- [ ] **AGENTS.md's "verify version after merge" is still a manual step.** PR#52's root cause
  (a bump landing back at the old value after merge) was never pinned down, so the only
  safeguard right now is a human remembering to diff `origin/main` after every merge.
  `release.yml`'s `detect` job already re-diffs every `devcontainer-feature.json` version on
  push to `main` for its own purposes — extending it to flag "this looks like a bump that
  should have landed didn't" would close the gap for real.

- [ ] **`peon-ping`'s `host.docker.internal` fix pushes a `runArgs` line onto every consumer**
  instead of patching `/etc/hosts` automatically at container start. Five other features in
  this repo already use `postCreateCommand`/`postStartCommand` for exactly this "must act on
  the live container" problem — worth checking whether the same pattern works here before
  asking every consumer to edit their own `devcontainer.json`.

- [ ] **AGENTS.md's feature table hand-maintains a `Ver` column** that duplicates each
  feature's own `devcontainer-feature.json` version, with nothing checking the two stay in
  sync. Low stakes on its own, but it's the same kind of duplication that let PR#52 drift
  silently — either generate the column or have the `shellcheck` CI job verify it.

- [ ] **`nub`: dedicated feature vs. folded into an existing one.** Asked for, not delivered
  yet — a real analysis of whether a standalone `nub` feature earns its keep versus, say,
  extending `package-auto-install` or `typescript-dev` to cover the same ground.

- [ ] **`pnpm-store` compatibility with `nub`.** Does `nub` delegating to `pnpm` respect the
  `store-dir` config `pnpm-store` sets up, or does each invocation end up with its own?
  Don't document the pairing as supported until someone's actually run it.

- [ ] **OpenSSF Scorecard.** Not set up anywhere in the org yet — `helpers4/typescript` has
  the workflow file but nothing registered on OpenSSF's side, so there's no working example
  to copy. Wait until that's sorted somewhere first.

- [ ] **`peon-ping` host relay reachability.** Whether the relay is actually reachable (not
  just DNS-resolvable) depends on what interface `peon relay --daemon` binds to on the host.
  Needs a real speaker and a real host to test — see the README's "Testing the audio path"
  section.
