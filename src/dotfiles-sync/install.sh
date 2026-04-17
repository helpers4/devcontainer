#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs dotfiles-sync devcontainer feature.
# This script runs at BUILD TIME — bind mounts are NOT available yet.
# File sync from mounts happens at container start via postStartCommand.

set -e

USERNAME="${_BUILD_ARG_USERNAME:-"${USERNAME:-"node"}"}"
SOURCE_HOME="/tmp/dotfiles-sync"

# Resolve target home robustly
if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
else
    TARGET_HOME="/home/${USERNAME}"
fi

echo "Setting up dotfiles-sync devcontainer feature..."
echo "   Container user: ${USERNAME}"
echo "   Home directory: ${TARGET_HOME}"
echo "   Mount staging: ${SOURCE_HOME}"
echo ""

# ============================================================================
# 1. Create directory structure (build time)
# ============================================================================

mkdir -p "${TARGET_HOME}/.ssh" "${TARGET_HOME}/.gnupg" 2>/dev/null || true
chmod 700 "${TARGET_HOME}/.ssh" "${TARGET_HOME}/.gnupg" 2>/dev/null || true
touch "${TARGET_HOME}/.gitconfig" "${TARGET_HOME}/.npmrc" 2>/dev/null || true

if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" \
        "${TARGET_HOME}/.ssh" \
        "${TARGET_HOME}/.gnupg" \
        "${TARGET_HOME}/.gitconfig" \
        "${TARGET_HOME}/.npmrc" 2>/dev/null || true
fi

echo "Directory structure created"

# ============================================================================
# 2. Install runtime sync script
# ============================================================================

mkdir -p /usr/local/share/dotfiles-sync

cat > /usr/local/share/dotfiles-sync/config << CONF_EOF
DOTFILES_SYNC_USERNAME="${USERNAME}"
DOTFILES_SYNC_SOURCE="${SOURCE_HOME}"
DOTFILES_SYNC_TARGET="${TARGET_HOME}"
CONF_EOF

cp "$(dirname "$0")/sync-files.sh" /usr/local/share/dotfiles-sync/sync-files.sh
chmod +x /usr/local/share/dotfiles-sync/sync-files.sh

echo "Runtime sync script installed (/usr/local/share/dotfiles-sync/sync-files.sh)"

# ============================================================================
# 3. Install SSH_AUTH_SOCK runtime detection (profile.d)
# ============================================================================

cat > /etc/profile.d/dotfiles-sync-ssh.sh << 'PROFILE_EOF'
# dotfiles-sync: SSH agent socket detection (runtime)
# ssh-add -l exits: 0 = keys loaded, 1 = no keys, 2 = cannot connect
# Accept 0 and 1 (agent alive), reject only 2 (dead/missing agent)
_DOTFILES_SYNC_SSH_SOCK="/tmp/dotfiles-sync/.ssh/agent.sock"

_dotfiles_sync_ssh_responds() {
    local _rc=0
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1 || _rc=$?
    [ "$_rc" -ne 2 ]
}

if [ -S "$_DOTFILES_SYNC_SSH_SOCK" ] && _dotfiles_sync_ssh_responds "$_DOTFILES_SYNC_SSH_SOCK"; then
    export SSH_AUTH_SOCK="$_DOTFILES_SYNC_SSH_SOCK"
elif [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ] && _dotfiles_sync_ssh_responds "$SSH_AUTH_SOCK"; then
    :
elif [ -S "/ssh-agent" ] && _dotfiles_sync_ssh_responds "/ssh-agent"; then
    export SSH_AUTH_SOCK="/ssh-agent"
fi

unset _DOTFILES_SYNC_SSH_SOCK
unset -f _dotfiles_sync_ssh_responds
PROFILE_EOF

chmod +x /etc/profile.d/dotfiles-sync-ssh.sh
echo "SSH agent detection installed (/etc/profile.d/dotfiles-sync-ssh.sh)"

# ============================================================================
# 4. Install one-time sync fallback (profile.d)
# ============================================================================

cat > /etc/profile.d/dotfiles-sync-sync.sh << 'PROFILE_EOF'
# dotfiles-sync: one-time file sync fallback
# Runs sync on first shell if postStartCommand hasn't completed yet
_DOTFILES_SYNC_MARKER="/tmp/.dotfiles-sync-synced"
if [ ! -f "$_DOTFILES_SYNC_MARKER" ] && [ -d "/tmp/dotfiles-sync" ]; then
    /usr/local/share/dotfiles-sync/sync-files.sh 2>/dev/null || true
fi
unset _DOTFILES_SYNC_MARKER
PROFILE_EOF

chmod +x /etc/profile.d/dotfiles-sync-sync.sh
echo "Sync fallback installed (/etc/profile.d/dotfiles-sync-sync.sh)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "dotfiles-sync feature installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Architecture:"
echo "   Build time  -> Directory structure + scripts installed"
echo "   Start time  -> postStartCommand syncs files from bind mounts"
echo "   Shell start -> SSH_AUTH_SOCK detection + sync fallback"
echo ""
echo "Targets:"
echo "   Git config  -> ${TARGET_HOME}/.gitconfig"
echo "   SSH keys    -> ${TARGET_HOME}/.ssh/"
echo "   GPG keys    -> ${TARGET_HOME}/.gnupg/"
echo "   npm tokens  -> ${TARGET_HOME}/.npmrc"
