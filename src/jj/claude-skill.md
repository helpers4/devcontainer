---
name: jj
description: Use in any repository with a .jj directory at its root, or when the user mentions jj or Jujutsu — before committing, amending, splitting, rebasing, pushing, branching or resolving conflicts there. How to do each with jj, non-interactively, in a jj repo colocated with git.
---

# Working in a jj (Jujutsu) repository

A `.jj` directory next to `.git` means the repo is a **colocated** jj repo: jj and git share
the same commits. Make every change to history with `jj`. Read-only git commands are fine
(`git log`, `git diff`, `git show`, `git blame`, `gh`).

Never run `git commit`, `git switch`/`git checkout <branch>`, `git rebase`, `git reset`,
`git stash` or `git worktree` here: jj keeps git's HEAD **detached on purpose**, and a commit
made on it belongs to no branch. A detached HEAD in `git status` is normal, not something to
fix.

## How jj differs from git

- The working copy **is** a commit, `@`. Every jj command first snapshots the files into it:
  there is no staging area and no `add`. A new file is tracked as soon as it exists (unless
  `.gitignore`d).
- `@-` is its parent, the last "real" commit. A commit is called a *change* and keeps its
  *change id* (letters like `kxqvzmpt`) when rewritten; its commit id (hex) changes.
- Branches are **bookmarks**. They don't move when you commit: move them yourself.
- Rewriting a commit rebases its descendants automatically. A conflict never stops a command:
  it gets recorded in the commit, to resolve whenever you want.
- Commits already on the trunk or on a remote's main branch are immutable: jj refuses to
  rewrite them. Don't pass `--ignore-immutable` unless the user asks for it.
- jj runs **no git hooks**. Run the repo's own checks (lint, tests, commit-message rules)
  yourself before pushing.

## Always non-interactive

Give every message on the command line, and never use `-i`/`--interactive`: an editor or a
diff editor would wait for input you can't give. In this container they fail at once with a
hint instead of hanging.

- `jj describe -m "msg"`, `jj commit -m "msg"`, `jj new -m "msg"`, `jj split -m "msg" PATHS`
- `jj squash` asks for a combined message when both sides have one: pass `-u` to keep the
  destination's, or `-m "msg"`.

## Commands

| Task | jj |
| ---- | -- |
| Status, log | `jj st`, `jj log`, `jj log -r 'trunk()..@'` |
| Diff | `jj diff` (`--git` for a patch), `jj show REV` |
| Commit the current work | `jj commit -m "msg"` (describes `@`, starts a new empty `@`) |
| Amend the last commit | `jj squash -u` (all of `@` into `@-`), or `jj squash -u PATHS` |
| Fold changes into the commits that last touched those lines | `jj absorb` |
| Move changes into any commit | `jj squash --into REV -u PATHS` |
| Split a commit | `jj split -r REV -m "first part" PATHS` |
| Reword | `jj describe -r REV -m "msg"` |
| Discard changes | `jj restore PATHS` (or `jj restore --from REV PATHS`) |
| Drop a commit | `jj abandon REV` |
| Start new work on the trunk | `jj git fetch`, then `jj new 'trunk()' -m "msg"` |
| Update a branch onto the trunk | `jj git fetch`, then `jj rebase -b @ -o 'trunk()'` |
| Create / move a bookmark | `jj bookmark create NAME -r @-`, `jj bookmark move NAME --to @-` |
| Follow a remote branch | `jj bookmark track NAME@origin` |
| Push | `jj git push --bookmark NAME` |
| Open a PR | push the bookmark, then `gh pr create --head NAME` |
| Parallel work (instead of git worktrees) | `jj workspace add ../REPO-TASK`; when done `jj workspace forget REPO-TASK` and delete the folder |
| Undo the last jj command | `jj undo` |
| Go back further | `jj op log`, then `jj op restore OPERATION_ID` |

`jj git push` refuses to overwrite a remote bookmark that moved since the last fetch (like
`git push --force-with-lease`), so pushing a rewritten branch needs no extra flag. Commits
with no description, or an author without an email, are refused: describe them first.

Useful revsets: `@`, `@-`, `trunk()`, `trunk()..@` (your stack), `mine()`, `conflicts()`,
`bookmarks()`, `REV::` (descendants), `::REV` (ancestors).

## Conflicts

`jj st` and `jj log -r 'conflicts()'` show them. To resolve one in commit `REV`:

1. `jj new REV` to work on top of it.
2. Edit each conflicted file and replace the whole block, from `<<<<<<<` to `>>>>>>>`, with
   the resolved content. jj's markers differ from git's: a `%%%%%%%` section is a diff from the
   base to one side (apply it), a `+++++++` section is the other side's content.
3. `jj st` until no conflict is listed, then `jj squash -u` to put the resolution into `REV`.
