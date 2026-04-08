#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs local-mounts devcontainer feature.
# This script runs at BUILD TIME — bind mounts are NOT available yet.
# File sync from mounts happens at container start via postStartCommand.

set -e

USERNAME="${_BUILD_ARG_USERNAME:-"${USERNAME:-"node"}"}"
SOURCE_HOME="/tmp/local-mounts"

# Resolve target home robustly
if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
else
    TARGET_HOME="/home/${USERNAME}"
fi

echo "🔧 Setting up local-mounts devcontainer feature..."
echo "   Container user: ${USERNAME}"
echo "   Home directory: ${TARGET_HOME}"
echo "   Mount staging: ${SOURCE_HOME}"
echo ""

# ============================================================================
# 1. Create directory structure (build time)
# ============================================================================
# Bind mounts are NOT available during docker build.
# Create the target directories so they exist when the container starts.

mkdir -p "${TARGET_HOME}/.ssh" "${TARGET_HOME}/.gnupg" 2>/dev/null || true
chmod 700 "${TARGET_HOME}/.ssh" "${TARGET_HOME}/.gnupg" 2>/dev/null || true
touch "${TARGET_HOME}/.gitconfig" "${TARGET_HOME}/.npmrc" 2>/dev/null || true

# Fix ownership for target user
if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" \
        "${TARGET_HOME}/.ssh" \
        "${TARGET_HOME}/.gnupg" \
        "${TARGET_HOME}/.gitconfig" \
        "${TARGET_HOME}/.npmrc" 2>/dev/null || true
fi

echo "✅ Directory structure created"

# ============================================================================
# 2. Install runtime sync script
# ============================================================================
# This script runs at container start (via postStartCommand) when bind mounts
# are available. It copies files from /tmp/local-mounts/ to the user's home.

mkdir -p /usr/local/share/local-mounts

# Store build-time configuration for runtime use
cat > /usr/local/share/local-mounts/config << CONF_EOF
LOCAL_MOUNTS_USERNAME="${USERNAME}"
LOCAL_MOUNTS_SOURCE="${SOURCE_HOME}"
LOCAL_MOUNTS_TARGET="${TARGET_HOME}"
CONF_EOF

cp "$(dirname "$0")/sync-files.sh" /usr/local/share/local-mounts/sync-files.sh
chmod +x /usr/local/share/local-mounts/sync-files.sh

echo "✅ Runtime sync script installed (/usr/local/share/local-mounts/sync-files.sh)"

# ============================================================================
# 3. Install SSH_AUTH_SOCK runtime detection (profile.d)
# ============================================================================
# Detects the best SSH agent socket at shell startup.
# Priority: 1) Stable host socket  2) VS Code native  3) Legacy /ssh-agent

cat > /etc/profile.d/local-mounts-ssh.sh << 'PROFILE_EOF'
# local-mounts: SSH agent socket detection (runtime)
# ssh-add -l exits: 0 = keys loaded, 1 = no keys, 2 = cannot connect
# We accept 0 and 1 (agent alive), reject only 2 (dead/missing agent)
_LOCAL_MOUNTS_SSH_SOCK="/tmp/local-mounts/.ssh/agent.sock"

_ssh_agent_responds() {
    local _rc=0
    SSH_AUTH_SOCK="$1" ssh-add -l >/dev/null 2>&1 || _rc=$?
    [ "$_rc" -ne 2 ]
}

if [ -S "$_LOCAL_MOUNTS_SSH_SOCK" ] && _ssh_agent_responds "$_LOCAL_MOUNTS_SSH_SOCK"; then
    # Stable host socket is mounted and agent responds
    export SSH_AUTH_SOCK="$_LOCAL_MOUNTS_SSH_SOCK"
elif [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ] && _ssh_agent_responds "$SSH_AUTH_SOCK"; then
    # VS Code's native SSH agent forwarding is working — keep it
    :
elif [ -S "/ssh-agent" ] && _ssh_agent_responds "/ssh-agent"; then
    # Legacy external mount
    export SSH_AUTH_SOCK="/ssh-agent"
fi

unset _LOCAL_MOUNTS_SSH_SOCK
unset -f _ssh_agent_responds
PROFILE_EOF

chmod +x /etc/profile.d/local-mounts-ssh.sh

echo "✅ SSH agent detection installed (/etc/profile.d/local-mounts-ssh.sh)"

# ============================================================================
# 4. Install one-time sync fallback (profile.d)
# ============================================================================
# Safety net: if postStartCommand didn't run (or hasn't finished yet),
# the first interactive shell triggers the sync.

cat > /etc/profile.d/local-mounts-sync.sh << 'PROFILE_EOF'
# local-mounts: one-time file sync fallback
# Runs sync on first shell if postStartCommand hasn't completed yet
_LOCAL_MOUNTS_MARKER="/tmp/.local-mounts-synced"
if [ ! -f "$_LOCAL_MOUNTS_MARKER" ] && [ -d "/tmp/local-mounts" ]; then
    /usr/local/share/local-mounts/sync-files.sh 2>/dev/null || true
fi
unset _LOCAL_MOUNTS_MARKER
PROFILE_EOF

chmod +x /etc/profile.d/local-mounts-sync.sh

echo "✅ Sync fallback installed (/etc/profile.d/local-mounts-sync.sh)"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 local-mounts feature installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Architecture:"
echo "   Build time  → Directory structure + scripts installed"
echo "   Start time  → postStartCommand syncs files from bind mounts"
echo "   Shell start → SSH_AUTH_SOCK detection + sync fallback"
echo ""
echo "📁 Targets:"
echo "   Git config  → ${TARGET_HOME}/.gitconfig"
echo "   SSH keys    → ${TARGET_HOME}/.ssh/"
echo "   GPG keys    → ${TARGET_HOME}/.gnupg/"
echo "   npm tokens  → ${TARGET_HOME}/.npmrc"
