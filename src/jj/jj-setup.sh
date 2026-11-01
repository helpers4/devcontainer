#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs as the container user, from the workspace folder:
#   create  (postCreateCommand, once per container) — volume ownership, Claude Code skill.
#   attach  (postAttachCommand, every attach) — identity and signing from git, repos turned
#           into colocated jj repos, version check against VisualJJ's own jj.
# attach waits for the attach on purpose: that is when the client has copied ~/.gitconfig in
# and helpers4-common's self-heal has repaired it, and jj needs the identity before it creates
# a single commit (a commit made without one stays authorless and can't be pushed).
#
# Best-effort: never fails the container start, only warns.

set -uo pipefail
# Nothing here asks for input: jj and git get no stdin to wait on or read from.
exec < /dev/null

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
# shellcheck source=/dev/null
. /usr/local/share/jj/options.env

STAGED="/mnt/h4jj"
# /etc/jj/conf.d/10-helpers4-git.toml links here: a file in the volume, which is made
# writable for the container user, whatever UID it ended up with (see install.sh).
GIT_CONF="${STAGED}/.helpers4-git.toml"
SKILL_SRC="/usr/local/share/jj/claude-skill.md"
SKILL_MARKER=".helpers4-jj"

log() { echo "[jj] $*"; }
warn() { echo "[jj] WARN: $*" >&2; }

if ! command -v jj > /dev/null 2>&1; then
    warn "jj is not on PATH, nothing to set up"
    exit 0
fi

# ── create ───────────────────────────────────────────────────────────────────

setup_volume() {
    if ! grep -qs " ${STAGED} " /proc/mounts; then
        warn "${STAGED} is not a mounted volume — ~/.config/jj won't survive a rebuild"
    fi
    # Exclusive to this devcontainer (${devcontainerId}), so no --shared — see
    # h4_ensure_volume_writable's own comment in helpers4-common/install.sh.
    h4_ensure_volume_writable "${STAGED}"
}

# install.sh gave /workspaces to the container user by name, but the devcontainer CLI may give
# that user the host's UID afterwards (updateRemoteUserUID) and only re-owns its home.
setup_workspaces() {
    [ -w /workspaces ] && return 0
    if ! { command -v sudo > /dev/null 2>&1 && sudo -n chown "$(id -u):$(id -g)" /workspaces 2> /dev/null; }; then
        warn "cannot write to /workspaces: VisualJJ can't create its workspaces there"
    fi
}

# Claude Code reads skills from <config dir>/skills/<name>/SKILL.md. claude-dev points
# CLAUDE_CONFIG_DIR at its volume, which it has made writable by now (this feature installs
# after it). Without claude-dev, ~/.claude, as long as Claude Code is around at all.
install_claude_skill() {
    [ "${CLAUDE_SKILL}" = "true" ] || return 0
    local config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}" target
    if [ -z "${CLAUDE_CONFIG_DIR:-}" ] && [ ! -d "${config_dir}" ] && ! command -v claude > /dev/null 2>&1; then
        return 0
    fi
    target="${config_dir}/skills/jj"
    # A jj skill without our marker is the user's own: never overwrite it.
    if [ -e "${target}" ] && [ ! -f "${target}/${SKILL_MARKER}" ]; then
        log "kept your own Claude Code skill in ${target}"
        return 0
    fi
    if mkdir -p "${target}" && cp "${SKILL_SRC}" "${target}/SKILL.md" \
        && echo "Managed by the helpers4 jj feature: replaced on every rebuild. Delete this file to keep your edits." > "${target}/${SKILL_MARKER}"; then
        log "Claude Code skill installed in ${target}"
    else
        warn "could not write the Claude Code skill to ${target}"
    fi
}

# ── attach: identity and signing ─────────────────────────────────────────────

toml_string() {
    local value="${1//\\/\\\\}"
    printf '"%s"' "${value//\"/\\\"}"
}

git_get() {
    git config --get "$@" 2>/dev/null || true
}

expand_home() {
    case "$1" in
        \~/*) printf '%s' "${HOME}/${1#\~/}" ;;
        *) printf '%s' "$1" ;;
    esac
}

# Prints jj's signing settings for what git signs with, or nothing (with a warning) when jj
# couldn't sign: with sign-on-push, a key it can't load makes every `jj git push` fail.
signing_config() {
    [ "$(git config --type=bool --get commit.gpgsign 2>/dev/null)" = "true" ] || return 0

    local format key program backend allowed
    format="$(git_get gpg.format)"
    key="$(git_get user.signingkey)"
    case "${format:-openpgp}" in
        openpgp)
            backend="gpg"
            program="$(git_get gpg.program)"
            [ -n "${program}" ] || program="gpg"
            ;;
        x509)
            backend="gpgsm"
            program="$(git_get gpg.x509.program)"
            [ -n "${program}" ] || program="gpgsm"
            ;;
        ssh)
            backend="ssh"
            program="$(git_get gpg.ssh.program)"
            [ -n "${program}" ] || program="ssh-keygen"
            # git takes either a key file or the key itself, prefixed key:: (or bare, in
            # older configs); jj takes both as is, without the prefix.
            key="${key#key::}"
            case "${key}" in
                ssh-* | ecdsa-* | sk-*) ;;
                "")
                    warn "git signs commits with SSH but sets no user.signingkey: jj won't sign"
                    return 0
                    ;;
                *)
                    key="$(expand_home "${key}")"
                    if [ ! -f "${key}" ]; then
                        warn "git's SSH signing key ${key} doesn't exist here: jj won't sign (it would fail every push)"
                        return 0
                    fi
                    ;;
            esac
            allowed="$(expand_home "$(git_get gpg.ssh.allowedSignersFile)")"
            ;;
        *)
            warn "git signs commits with gpg.format=${format}, which jj doesn't support: jj won't sign"
            return 0
            ;;
    esac
    if ! command -v "${program%% *}" > /dev/null 2>&1; then
        warn "git signs commits with ${program}, which isn't installed here: jj won't sign"
        return 0
    fi

    # jj rewrites commits all the time (every snapshot of the working copy): signing each one
    # would mean a passphrase or agent prompt per command. jj's own recommendation: sign on
    # push instead, which is when signatures start to matter.
    echo 'signing.behavior = "drop"'
    echo "signing.backend = $(toml_string "${backend}")"
    [ -n "${key}" ] && echo "signing.key = $(toml_string "${key}")"
    echo "signing.backends.${backend}.program = $(toml_string "${program}")"
    [ -n "${allowed}" ] && echo "signing.backends.ssh.allowed-signers = $(toml_string "${allowed}")"
    echo 'git.sign-on-push = true'
}

sync_git_identity() {
    [ "${GIT_IDENTITY}" = "true" ] || return 0
    command -v git > /dev/null 2>&1 || return 0
    if [ ! -w "${STAGED}" ]; then
        warn "${STAGED} is not writable: jj won't get your git identity"
        return 0
    fi

    local name email signing tmp
    name="$(git_get user.name)"
    email="$(git_get user.email)"
    signing="$(signing_config)"
    # Replaced, not rewritten in place: an attach run as root (images without a remoteUser)
    # leaves a root-owned file that the container user can't open for writing.
    tmp="$(mktemp "${GIT_CONF}.XXXXXX")" || return 0
    {
        echo "# Written by the helpers4 jj feature on every attach, from your git config."
        echo "# Your own jj config (jj config set --user ...) overrides anything here."
        [ -n "${name}" ] && echo "user.name = $(toml_string "${name}")"
        [ -n "${email}" ] && echo "user.email = $(toml_string "${email}")"
        [ -n "${signing}" ] && echo "${signing}"
    } > "${tmp}"
    chmod 644 "${tmp}"
    mv -f "${tmp}" "${GIT_CONF}"

    if [ -n "${email}" ]; then
        log "identity from git: ${name:-<no name>} <${email}>${signing:+, signed on push}"
    else
        warn "git has no user.email: set it (git config --global user.email ...) or jj commits can't be pushed"
    fi
}

# ── attach: repos ────────────────────────────────────────────────────────────

# Repos in scope, one per line, deduplicated by real path (org-workspace's /workspaces/<name>
# are links into its volume). workspace: the repo holding the workspace folder. all and auto:
# that one and every repo next to it — or inside the workspace folder, when it isn't a repo
# itself.
list_repos() {
    local top base dir
    top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    {
        [ -n "${top}" ] && echo "${top}"
        if [ "${INIT_REPOS}" = "all" ] || [ "${INIT_REPOS}" = "auto" ]; then
            if [ -n "${top}" ]; then base="$(dirname "${top}")"; else base="${PWD}"; fi
            # Next to a repo in the home folder are dotfile repos (~/.oh-my-zsh...), not projects.
            case "$(readlink -f "${base}")" in
                / | "$(readlink -f "${HOME}")") base="" ;;
            esac
            [ -n "${base}" ] && for dir in "${base}"/* "${base}"/.[!.]*; do
                [ -e "${dir}/.git" ] && echo "${dir}"
            done
        fi
    } | while IFS= read -r dir; do readlink -f "${dir}"; done | awk '!seen[$0]++'
}

# True when the repo's recent history, on any local or remote branch, holds a commit made
# with jj: jj writes a "change-id" header into every git commit it creates, and GitHub keeps
# it through a push and a rebase merge (not a squash merge, hence the remote branches too).
# It's the only trace jj leaves in the repo itself — .jj is never committed — so a fresh
# clone of a repo you work on with jj is recognized, and a plain git repo never is.
has_jj_history() {
    local dir="$1"
    # awk reads everything instead of stopping at the first match: an early exit would kill
    # cat-file with SIGPIPE, and pipefail would turn the match into a failure.
    git -C "${dir}" rev-list -n 200 --branches --remotes HEAD 2>/dev/null \
        | git -C "${dir}" cat-file --batch 2>/dev/null \
        | awk '
            /^[0-9a-f]+ commit [0-9]+$/ { header = 1; next }
            header && $0 == "" { header = 0 }
            header && /^change-id / { found = 1 }
            END { exit !found }'
}

# Why a git checkout must stay as it is, or nothing if it can be turned into a jj repo.
init_blocker() {
    local dir="$1" git_dir state
    # jj git init would make it a second jj repo over the same git one.
    if [ -f "${dir}/.git" ]; then
        echo "it's a git worktree (turn its main checkout into a jj repo, then jj workspace add)"
        return
    fi
    git_dir="${dir}/.git"
    if [ "$(git -C "${dir}" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]; then
        echo "it's a shallow clone, which jj can't deepen later (git fetch --unshallow, then jj git init)"
        return
    fi
    [ -f "${dir}/.gitmodules" ] && { echo "it has submodules, which jj doesn't handle"; return; }
    if git -C "${dir}" grep -q 'filter=lfs' -- ':(glob)**/.gitattributes' 2>/dev/null; then
        echo "it uses Git LFS, which jj doesn't handle (it would commit the real files)"
        return
    fi
    for state in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD BISECT_LOG rebase-merge rebase-apply; do
        if [ -e "${git_dir}/${state}" ]; then
            echo "a git merge, rebase, cherry-pick or bisect is in progress (retried on the next attach)"
            return
        fi
    done
}

# jj's equivalent of git's upstream branches: a local branch that follows a same-named one on
# its remote gets its jj bookmark tracking it, so `jj git fetch` and `jj git push` move them
# together, as git pull/push did.
track_upstreams() {
    local dir="$1" branch remote upstream
    # Read from fd 3: jj reads stdin, and would swallow the rest of the list.
    while IFS=$'\t' read -r branch remote upstream <&3; do
        [ -n "${remote}" ] && [ "${upstream}" = "${remote}/${branch}" ] || continue
        jj -R "${dir}" bookmark track "${branch}@${remote}" --quiet 2>/dev/null || true
    done 3< <(git -C "${dir}" for-each-ref --format='%(refname:short)%09%(upstream:remotename)%09%(upstream:short)' refs/heads 2>/dev/null)
}

init_repo() {
    local dir="$1" name blocker out
    name="$(basename "${dir}")"
    blocker="$(init_blocker "${dir}")"
    if [ -n "${blocker}" ]; then
        log "${name}: left as a plain git repo: ${blocker}"
        return
    fi
    # Colocated whatever git.colocate says: the checkout's .git has to stay where git tools
    # expect it.
    if ! out="$(cd "${dir}" && jj git init --colocate 2>&1)"; then
        warn "${name}: jj git init failed: ${out}"
        return
    fi
    CONVERTED=$((CONVERTED + 1))
    track_upstreams "${dir}"
    log "${name}: now a colocated jj repo (git still works; git's HEAD gets detached on the first jj change)"

    if [ -n "$(git -C "${dir}" config --get core.hooksPath 2>/dev/null)" ] \
        || find "${dir}/.git/hooks" -maxdepth 1 -type f ! -name '*.sample' 2>/dev/null | grep -q .; then
        warn "${name}: has git hooks, which jj never runs: run those checks yourself before jj git push"
    fi
    if [ -f "${dir}/.git/.graphite_repo_config" ]; then
        warn "${name}: uses Graphite: gt needs a checked-out branch, which jj leaves detached"
    fi
}

# A working-copy commit created while jj had no identity (before the git config was there)
# stays authorless, and jj refuses to push it: give it the identity now there is one.
heal_author() {
    local dir="$1"
    [ -n "$(jj -R "${dir}" config get user.email 2>/dev/null)" ] || return 0
    [ -z "$(jj -R "${dir}" log --ignore-working-copy --no-graph -r @ -T 'author.email()' 2>/dev/null)" ] || return 0
    if jj -R "${dir}" metaedit --update-author --quiet 2> /dev/null; then
        log "$(basename "${dir}"): working-copy commit given your identity"
    fi
}

# org-workspace marks jj repos in the .code-workspace folder names, but it writes them when the
# container is created, before the first attach converts anything: run it again so a repo
# converted just now shows up as one right away. It's idempotent, and only runs after a
# conversion, so at most once per new jj repo.
refresh_org_workspace() {
    local script="/usr/local/share/org-workspace/clone-repos.sh"
    [ "${CONVERTED}" -gt 0 ] && [ -x "${script}" ] || return 0
    "${script}"
}

setup_repos() {
    [ "${INIT_REPOS}" = "off" ] && return 0
    command -v git > /dev/null 2>&1 || return 0
    local dir
    local -a plain=()
    CONVERTED=0
    # Read from fd 3: jj reads stdin, and would swallow the rest of the list.
    while IFS= read -r dir <&3; do
        [ -n "${dir}" ] || continue
        if [ ! -d "${dir}/.jj" ]; then
            if [ "${INIT_REPOS}" = "auto" ] && ! has_jj_history "${dir}"; then
                plain+=("$(basename "${dir}")")
                continue
            fi
            init_repo "${dir}"
        fi
        [ -d "${dir}/.jj" ] && heal_author "${dir}"
    done 3< <(list_repos)

    if [ "${#plain[@]}" -gt 0 ]; then
        log "plain git, no jj commit in their history: ${plain[*]} (run jj git init in one to switch it to jj)"
    fi
    refresh_org_workspace
}

# ── attach: VisualJJ ─────────────────────────────────────────────────────────

minor_version() {
    "$@" --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1
}

# VisualJJ runs its own jj build (it adds commands the extension needs), on the same repo as
# the CLI: keep both on the same release. Nothing to compare until VS Code has installed the
# extension, which may still be going on during the very first attach.
check_visualjj() {
    local bundled cli_version bundled_version
    bundled="$(find "${HOME}"/.vscode-server*/extensions "${HOME}"/.cursor-server/extensions \
        -maxdepth 4 -path '*/visualjj.visualjj-*/dist/bin/jj' -type f 2>/dev/null | sort -V | tail -1)"
    [ -n "${bundled}" ] && [ -x "${bundled}" ] || return 0

    cli_version="$(minor_version jj)"
    bundled_version="$(minor_version timeout 5 "${bundled}")"
    if [ -n "${cli_version}" ] && [ -n "${bundled_version}" ] && [ "${cli_version}" != "${bundled_version}" ]; then
        warn "VisualJJ uses jj ${bundled_version}, the jj CLI is ${cli_version}: set this feature's \"version\" to the same release"
    fi
    # VisualJJ starts Claude Code from its CLI, not from the VS Code extension.
    if [ -n "${CLAUDE_CONFIG_DIR:-}" ] && ! command -v claude > /dev/null 2>&1; then
        log "VisualJJ's Claude Code integration needs the claude CLI: set claude-dev's \"installCli\": true"
    fi
}

case "${1:-}" in
    create)
        setup_volume
        setup_workspaces
        install_claude_skill
        ;;
    attach)
        sync_git_identity
        setup_repos
        check_visualjj
        ;;
    *)
        echo "Usage: $0 create|attach" >&2
        exit 1
        ;;
esac
exit 0
