# Jujutsu (jj)

> Code name: `jj`

Installs [jj (Jujutsu)](https://jj-vcs.github.io/jj/), a version control system that works on
top of your Git repos, and the [VisualJJ](https://www.visualjj.com/) extension. Open the
devcontainer and start using `jj`: nothing else to set up.

- **The repos you use jj in become jj repos**, colocated with git: `jj` and `git` both work
  in them, and your team, CI and GitHub still only see Git. Repos you only use git in are
  left untouched, so a workspace can mix both.
- **jj gets your git identity and commit signing**, on every attach. jj never reads git's
  config on its own: without this, its commits would have no author and couldn't be pushed.
- **Your jj config survives rebuilds**, in a Docker named volume dedicated to this
  devcontainer.
- **AI agents can use jj safely**: in a Claude Code session, jj never opens an editor or a TUI
  that would hang the agent, and Claude Code gets a skill that tells it to use jj instead of
  git in jj repos.

> **Also included automatically:** repairs broken host paths in your git config and restores
> your SSH commit-signing key on every attach, on both local and cloud containers, with nothing
> to set up on your end — see [`helpers4-common`](../helpers4-common) for how it works.

## When to use this

Use this when you want to work with jj — from the terminal, from VisualJJ, or through an AI
agent — in a project that is, and stays, a Git repo.

**Alternatives:**
- VisualJJ alone: it brings its own jj, but only to its integrated terminals, and Claude Code
  never sees it.
- [Jujutsu Kaizen](https://marketplace.visualstudio.com/items?itemName=jjk.jjk) is an
  open-source alternative to VisualJJ: add `"jjk.jjk"` to your extensions (it uses the jj
  this feature installs).

## Usage

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/jj:1": {}
  }
}
```

No `initializeCommand` required — Docker creates the volume automatically the first time it's
needed.

With Claude Code and an [`org-workspace`](../org-workspace): the org's repos you use jj in
become jj repos, the others stay plain git, and the workspace's folder names say which is which
(`🔒 api (jj)`):

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/claude-dev:1": { "installCli": true },
    "ghcr.io/helpers4/devcontainer/org-workspace:1": { "org": "my-org" },
    "ghcr.io/helpers4/devcontainer/jj:1": {}
  }
}
```

Without VisualJJ:

```jsonc
{
  "features": {
    "ghcr.io/helpers4/devcontainer/jj:1": {}
  },
  "customizations": {
    "vscode": {
      "extensions": ["-visualjj.visualjj"]
    }
  }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `username` | string | `auto` | Container user who uses jj. `auto` detects vscode/node/codespace/uid-1000, in that order. |
| `version` | string | `latest` | jj version to install: `latest`, or a release such as `0.46.0`. |
| `initRepos` | string | `auto` | Git repos to turn into colocated jj repos: `auto` (those you already use jj in, among the repo you opened and the ones next to it), `workspace` (the repo you opened), `all` (it and every repo next to it), `off` (none). See [Your repos](#your-repos). |
| `gitIdentity` | boolean | `true` | Give jj the name, email and commit signing of your git config, on every attach. See [Identity and signing](#identity-and-signing). |
| `claudeSkill` | boolean | `true` | Add a jj skill to Claude Code, when Claude Code is in the container. See [AI agents](#ai-agents). |

## Your repos

On every attach, each repo in `initRepos`' scope that isn't a jj repo yet is turned into one
with `jj git init --colocate`:

- `auto` (default): among the repo of the folder you opened and every git repo next to it, the
  ones **you already use jj in**. The others stay plain git, untouched.
- `workspace`: the repo of the folder you opened, whatever it holds.
- `all`: that repo and every git repo next to it, whatever they hold.
- `off`: none. Run `jj git init` in a repo yourself when you want it.

"Next to it" means in the same folder — `/workspaces`, where [`org-workspace`](../org-workspace)
clones its repos — or, when the folder you opened isn't a repo itself, inside it. Never next to
a repo in your home folder, where the neighbours are dotfile repos (`~/.oh-my-zsh`).

### How `auto` recognizes a jj repo

`.jj` is local, never committed: a fresh clone of a repo you work on with jj looks like any
other git repo. But every commit jj creates carries a `change-id` header in its git object, and
GitHub keeps it through a push and a rebase merge. So `auto` converts a repo when one of the
last 200 commits of its branches, local or remote, has that header: you, or a teammate, already
work on it with jj. A repo that only ever saw git has none, and stays as it is.

- A repo you want to start using jj in: run `jj git init` in it once. It stays a jj repo (its
  `.jj` folder is kept, in `org-workspace`'s volume or your project folder), and once you've
  pushed from jj, every new clone of it is recognized too.
- A repo whose PRs are squash-merged: the squashed commits on `main` lose the header, but the
  PR branches still on the remote keep it.
- A repo you want to keep plain git although someone pushed jj commits to it: set
  `initRepos` to `workspace` or `off`.

With `auto`, the attach log lists the repos left as plain git.

### What changes in a jj repo

**Colocated** means the repo keeps its `.git` where it is: every git tool, IDE extension, CI
job and `gh` command keeps working, and jj adds a `.jj` folder that git ignores. Nothing is
rewritten or pushed. What changes for git:

- **git's HEAD is detached** after the first jj command that changes something: jj tracks
  branches as *bookmarks* and doesn't keep one checked out. `git status` shows
  `HEAD detached` — that's normal. Run `git switch <branch>` before using a git command that
  needs a branch (or Graphite's `gt`).
- **jj runs no git hooks.** A pre-commit or commit-msg hook doesn't run on `jj commit`: run
  those checks yourself before `jj git push`. You get a warning for a repo that has hooks.

Each local branch that follows a same-named branch on its remote gets a bookmark that tracks
it, so `jj git fetch` / `jj git push` update them as `git pull` / `git push` did.

A repo is **left as a plain git repo**, with the reason in the attach log, when jj can't handle
it:

| Repo | Why |
|------|-----|
| A shallow clone | jj can't deepen it later. Run `git fetch --unshallow`, then `jj git init`. |
| With submodules | jj ignores them. |
| Using Git LFS | jj doesn't run git's filters: it would commit the real files. |
| A git worktree | `jj git init` would make it a second jj repo over the same git repo: turn its main checkout into a jj repo, then use `jj workspace add`. |
| In the middle of a merge, rebase, cherry-pick or bisect | Retried on the next attach. |

To go back to git only, delete the `.jj` folder and `git switch` back to your branch.

### With `org-workspace`

[`org-workspace`](../org-workspace) (v1.2.0+) adds `(jj)` to the folder name of each jj repo in
the `.code-workspace` file, e.g. `🔒 api (jj)`: in a workspace that mixes jj and plain git repos,
you see which is which. When this feature converts a repo, it runs `org-workspace` again, so the
name changes right away instead of at the next rebuild.

A jj repo's clone is never deleted by `org-workspace`'s cleanup: git sees its `.jj` folder as an
ignored file, which counts as possible local work.

## Identity and signing

jj has its own config and never reads git's. With `gitIdentity`, the name, email and signing
settings of your git config — after the client has copied it in and `helpers4-common` has
repaired it — are written to `/etc/jj/conf.d/10-helpers4-git.toml` on every attach. That's
jj's system config: anything you set yourself with `jj config set --user` wins over it.

| git | jj |
|-----|----|
| `user.name`, `user.email` | `user.name`, `user.email` |
| `commit.gpgsign = true` | `signing.behavior = "drop"` + `git.sign-on-push = true` |
| `gpg.format` (`openpgp` / `x509` / `ssh`) | `signing.backend` (`gpg` / `gpgsm` / `ssh`) |
| `user.signingkey` | `signing.key` |
| `gpg.program`, `gpg.x509.program`, `gpg.ssh.program` | `signing.backends.<backend>.program` |
| `gpg.ssh.allowedSignersFile` | `signing.backends.ssh.allowed-signers` |

jj rewrites commits all the time (each command snapshots your files into the working-copy
commit), so signing each one would mean a passphrase or agent prompt per command: commits are
signed when you push them instead, which is jj's own recommendation.

Signing is left off, with a warning, when jj couldn't sign: an SSH key file that doesn't exist
in the container, a signing program that isn't installed, `gpg.format` unknown to jj. Turning
it on anyway would make every `jj git push` fail.

A working-copy commit created before the identity was there (jj ran before the first attach)
gets it afterwards, with `jj metaedit --update-author`: jj refuses to push an authorless commit.

## AI agents

**Non-interactive jj.** When jj runs in an AI agent session — `CLAUDECODE` or `AI_AGENT` set,
as Claude Code does — `/etc/jj/conf.d/50-helpers4-agents.toml` turns the pager off and replaces
the editor, diff editor and merge tool with a command that fails at once and says what to do
instead (`-m "message"`, file paths, editing the conflict markers). Without it, `jj describe`,
`jj squash` or `jj split` would open an editor the agent can't see and hang until it times out.
Your own terminal is unaffected.

**Claude Code skill.** With `claudeSkill`, a `jj` skill is installed in Claude Code's config
(`$CLAUDE_CONFIG_DIR/skills/jj`, i.e. [`claude-dev`](../claude-dev)'s volume, or
`~/.claude/skills/jj`) when the container is created. Claude Code loads it in any repo with a
`.jj` folder: use jj for every change, never `git commit` / `git switch` on the detached HEAD,
the jj command for each git habit, conflicts, `jj undo`. A `skills/jj` you wrote yourself is
never overwritten; this one is replaced on each rebuild (delete its `.helpers4-jj` file to keep
your edits).

**VisualJJ and Claude Code.** VisualJJ can run Claude Code in a jj workspace of its own (beta).
It starts the `claude` CLI, not the VS Code extension: with `claude-dev`, set
`"installCli": true` — you get a reminder in the attach log otherwise. Its workspaces are
folders next to the repo, in `/workspaces`, which this feature makes writable for the container
user. They aren't in a volume: commit what you want to keep, as a rebuild removes them.

## VisualJJ

The [VisualJJ](https://www.visualjj.com/) extension (`visualjj.visualjj`) is installed: a
commit graph, drag & drop rebases, stacked PRs on GitHub. It is free for solo developers;
some features (auto-fetch, CI status, stacked PR automation) need a
[Pro licence](https://www.visualjj.com/docs/licensing). It isn't open source.

VisualJJ runs its own jj build, which it keeps up to date with jj's releases. Two settings
come with this feature:

- `visualjj.addJJToTerminalPath: false`: integrated terminals use this feature's `jj`, the same
  one Claude Code and scripts use, instead of VisualJJ's.
- If the two differ (VisualJJ on jj 0.46, the CLI on 0.47, for instance), you get a warning on
  attach: both work on the same repo, so set `version` to VisualJJ's release.

## How it works

1. **Build time** (`install.sh`):
   - downloads `jj` from its [GitHub releases](https://github.com/jj-vcs/jj/releases) (musl
     build, amd64 or arm64) to `/usr/local/bin/jj`;
   - writes bash, zsh and fish completions in their system-wide directories;
   - writes `/etc/jj/conf.d/50-helpers4-agents.toml`, and creates
     `/etc/jj/conf.d/10-helpers4-git.toml` owned by the container user;
   - links `~/.config/jj` (jj's user config) to `/mnt/h4jj`;
   - gives `/workspaces` to the container user (VisualJJ's workspaces).
2. **Mount** (`devcontainer-feature.json → mounts`): the Docker named volume
   `helpers4-jj-config-${devcontainerId}` is attached at `/mnt/h4jj`.
3. **Once per container** (`postCreateCommand`, `jj-setup.sh create`): makes the volume
   writable by the container user, installs the Claude Code skill.
4. **Every attach** (`postAttachCommand`, `jj-setup.sh attach`): identity and signing from git,
   repos turned into jj repos (then `org-workspace`'s folder names refreshed), VisualJJ version
   check.

Every step only warns when something goes wrong: the container always starts. To run the attach
step again by hand: `/usr/local/share/jj/jj-setup.sh attach`, from the workspace folder.

```text
/usr/local/bin/jj
/etc/jj/conf.d/
├── 10-helpers4-git.toml      (from your git config, every attach)
└── 50-helpers4-agents.toml   (AI agent sessions only)
~/.config/jj -> /mnt/h4jj     (volume, 700: your own jj config)
```

## OS and Architecture Support

- **OS:** Linux (Debian/Ubuntu-based images)
- **Architectures:** amd64, arm64

## Version History

- **v1.0.0**: Initial release.
