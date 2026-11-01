#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — the named volume is NOT attached yet.
# Installs jj (Jujutsu) from its GitHub releases, its shell completions, the system config
# under /etc/jj/conf.d, ~/.config/jj pointed at the /mnt/h4jj volume, and jj-setup.sh, which
# does the rest once the container runs (see README "How it works").

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

h4_require_root

# Feature options
JJ_VERSION="${VERSION:-"latest"}"
INIT_REPOS="${INITREPOS:-"workspace"}"
GIT_IDENTITY="${GITIDENTITY:-"true"}"
CLAUDE_SKILL="${CLAUDESKILL:-"true"}"
# USERNAME is injected by the devcontainer CLI from the 'username' feature option.
USERNAME="${USERNAME:-"automatic"}"
h4_detect_user
h4_resolve_home

case "${INIT_REPOS}" in
    workspace | all | off) ;;
    *)
        echo "(!) initRepos must be workspace, all or off, got '${INIT_REPOS}'" >&2
        exit 1
        ;;
esac

SHARE_DIR="/usr/local/share/jj"
CONF_DIR="/etc/jj/conf.d"
STAGED="/mnt/h4jj"
USER_GROUP="$(id -gn "${USERNAME}" 2>/dev/null || echo "${USERNAME}")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# The release archive holds a "./" entry: extracted straight into /tmp, it would reset
# /tmp's own permissions (1777 -> 755) and break every other user's temp files.
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
    rm -rf /var/lib/apt/lists/*
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing jj feature..."
echo "  Username:     ${USERNAME}"
echo "  jj version:   ${JJ_VERSION}"
echo "  initRepos:    ${INIT_REPOS}"
echo "  gitIdentity:  ${GIT_IDENTITY}"
echo "  claudeSkill:  ${CLAUDE_SKILL}"

h4_ensure_packages curl ca-certificates tar git

# ── jj binary ────────────────────────────────────────────────────────────────
architecture="$(h4_arch_musl_triple)" || exit 1

if [ "${JJ_VERSION}" = "latest" ]; then
    JJ_VERSION="$(h4_github_latest_tag jj-vcs/jj)"
    if [ -z "${JJ_VERSION}" ]; then
        echo "(!) Failed to fetch the latest jj version" >&2
        exit 1
    fi
fi
# Release tags carry a 'v' prefix (v0.46.0); accept the option with or without it.
JJ_TAG="v${JJ_VERSION#v}"

DOWNLOAD_URL="https://github.com/jj-vcs/jj/releases/download/${JJ_TAG}/jj-${JJ_TAG}-${architecture}.tar.gz"
echo "  📦 Downloading jj ${JJ_TAG}..."
if ! curl -fsSL "${DOWNLOAD_URL}" -o "${TMP_DIR}/jj.tar.gz"; then
    echo "(!) Failed to download jj from ${DOWNLOAD_URL}" >&2
    echo "(!) Available releases: https://github.com/jj-vcs/jj/releases" >&2
    exit 1
fi
tar -xzf "${TMP_DIR}/jj.tar.gz" -C "${TMP_DIR}"
if [ ! -f "${TMP_DIR}/jj" ]; then
    echo "(!) No jj binary in the downloaded archive" >&2
    exit 1
fi
install -m 0755 "${TMP_DIR}/jj" /usr/local/bin/jj

if ! INSTALLED_VERSION="$(/usr/local/bin/jj --version 2>&1)"; then
    echo "(!) jj installation verification failed: ${INSTALLED_VERSION}" >&2
    exit 1
fi
echo "  ✅ ${INSTALLED_VERSION} installed in /usr/local/bin/jj"

# ── Shell completions ────────────────────────────────────────────────────────
# Static scripts, in each shell's system-wide directory: nothing to add to ~/.bashrc or
# ~/.zshrc, and every user of the image gets them.
mkdir -p /usr/share/bash-completion/completions /usr/local/share/zsh/site-functions
jj util completion bash > /usr/share/bash-completion/completions/jj
jj util completion zsh > /usr/local/share/zsh/site-functions/_jj
COMPLETIONS="bash zsh"
if command -v fish > /dev/null 2>&1; then
    mkdir -p /usr/share/fish/vendor_completions.d
    jj util completion fish > /usr/share/fish/vendor_completions.d/jj.fish
    COMPLETIONS="${COMPLETIONS} fish"
fi
echo "  ✅ Completions: ${COMPLETIONS}"

# ── System config (/etc/jj/conf.d) ───────────────────────────────────────────
# jj's lowest-priority config layer after its built-in defaults: anything the user sets with
# `jj config set --user` (or a repo's own config) overrides it.
mkdir -p "${CONF_DIR}"

# An agent has no terminal to type in: an editor or a TUI it can't see would hang the
# command until it times out. In an agent session, these fail at once and say what to do
# instead. CLAUDECODE is set by Claude Code (CLI, VS Code extension, Remote Control);
# AI_AGENT by Claude Code too and by other agents that follow the same convention.
cat > "${CONF_DIR}/50-helpers4-agents.toml" << 'EOF'
# Written by the helpers4 jj feature. Only applies when jj runs inside an AI agent session.
[[--scope]]
--when.environments = ["CLAUDECODE", "AI_AGENT"]
[--scope.ui]
paginate = "never"
editor = ["sh", "-c", 'echo "jj: no editor in an agent session: pass the description with -m (jj squash: -u keeps the destination one)" >&2; exit 1', "jj-editor"]
diff-editor = ["sh", "-c", 'echo "jj: no interactive diff editor in an agent session: name the paths instead, e.g. jj split -m MESSAGE PATHS, jj squash PATHS, jj restore PATHS" >&2; exit 1', "jj-diff-editor"]
merge-editor = ["sh", "-c", 'echo "jj: no merge tool in an agent session: edit the conflict markers in the files, then check with jj st" >&2; exit 1', "jj-merge-editor"]
EOF
echo "  ✅ ${CONF_DIR}/50-helpers4-agents.toml (non-interactive jj for AI agents)"

# Rewritten on every attach by jj-setup.sh, as the container user, from the git config the
# client has just copied in: owned by that user so no sudo is needed then.
GIT_CONF="${CONF_DIR}/10-helpers4-git.toml"
if [ "${GIT_IDENTITY}" = "true" ]; then
    printf '# Written by the helpers4 jj feature on every attach, from your git config.\n' > "${GIT_CONF}"
    chown "${USERNAME}:${USER_GROUP}" "${GIT_CONF}"
    chmod 644 "${GIT_CONF}"
    echo "  ✅ ${GIT_CONF} (identity and signing from git, filled on attach)"
else
    rm -f "${GIT_CONF}"
fi

# ── ~/.config/jj in the volume ───────────────────────────────────────────────
# The mount point is created here, owned by the target user and private (the config holds
# your identity): Docker copies a mount point's content and ownership into an empty named
# volume the first time it's attached. A config written earlier in the build moves along.
mkdir -p "${STAGED}"
USER_CONFIG="${USER_HOME}/.config/jj"
mkdir -p "${USER_HOME}/.config"
chown "${USERNAME}:${USER_GROUP}" "${USER_HOME}/.config"
if [ -d "${USER_CONFIG}" ] && [ ! -L "${USER_CONFIG}" ]; then
    cp -a "${USER_CONFIG}/." "${STAGED}/"
    rm -rf "${USER_CONFIG}"
fi
ln -sfn "${STAGED}" "${USER_CONFIG}"
chown -h "${USERNAME}:${USER_GROUP}" "${USER_CONFIG}"
chown -R "${USERNAME}:${USER_GROUP}" "${STAGED}"
chmod 700 "${STAGED}"
echo "  ✅ ${USER_CONFIG} -> ${STAGED} (kept across rebuilds)"

# ── /workspaces writable ─────────────────────────────────────────────────────
# VisualJJ creates its jj workspaces (one per agent task, among others) as sibling folders of
# the repo, which sits in /workspaces: root-owned unless something gives it to the user.
mkdir -p /workspaces
if [ "${USERNAME}" != "root" ]; then
    chown "${USERNAME}:${USER_GROUP}" /workspaces \
        || echo "  ⚠️  Could not chown /workspaces to ${USERNAME}: VisualJJ can't create workspaces there" >&2
fi

# ── Runtime script ───────────────────────────────────────────────────────────
mkdir -p "${SHARE_DIR}"
install -m 0755 "${SCRIPT_DIR}/jj-setup.sh" "${SHARE_DIR}/jj-setup.sh"
install -m 0644 "${SCRIPT_DIR}/claude-skill.md" "${SHARE_DIR}/claude-skill.md"
# The options only exist as env vars during this install, so save them for jj-setup.sh.
{
    printf 'INIT_REPOS=%q\n' "${INIT_REPOS}"
    printf 'GIT_IDENTITY=%q\n' "${GIT_IDENTITY}"
    printf 'CLAUDE_SKILL=%q\n' "${CLAUDE_SKILL}"
} > "${SHARE_DIR}/options.env"
echo "  ✅ ${SHARE_DIR}/jj-setup.sh"

echo
echo "🎉 jj installation complete!"
echo
echo "📋 Usage:"
echo "  jj st                       # What changed (no staging: the working copy is a commit)"
echo "  jj commit -m 'message'      # Describe the current change and start a new one"
echo "  jj git push --bookmark NAME # Push a bookmark (jj's branches)"
echo "  jj undo                     # Undo the last jj operation"
echo
