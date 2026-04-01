#!/usr/bin/env bash

# Local Mounts DevContainer Feature
# Copyright (c) 2025 helpers4
# Licensed under LGPL-3.0 - see LICENSE file for details
#
# Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer
# for a configurable container user (default: node)
# This script runs INSIDE the container to verify and fix mounts

set -e

USERNAME="${_BUILD_ARG_USERNAME:-node}"
SOURCE_HOME="/tmp/local-mounts"

# Resolve target home robustly
if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
else
    TARGET_HOME="/home/${USERNAME}"
fi

echo "🔧 Setting up local-mounts devcontainer feature..."
echo "📁 Container user: ${USERNAME}"
echo "📁 Home directory: ${TARGET_HOME}"
echo "📁 Mount staging: ${SOURCE_HOME}"
echo ""

# ============================================================================
# CRITICAL: Verify mounts worked and create fallbacks if needed
# ============================================================================
# Docker bind mounts may fail silently. This section ensures all
# configuration files exist in the target home for the configured user.

_sync_file_from_mount() {
    local source_file="$1"
    local target_file="$2"
    local config_name="$3"

    if [ -f "${source_file}" ]; then
        cp -f "${source_file}" "${target_file}" 2>/dev/null || true
        echo "✅ ${config_name} synchronized to ${target_file}"
    elif [ ! -f "${target_file}" ]; then
        touch "${target_file}" 2>/dev/null || true
        echo "ℹ️  ${config_name} mount source not found, created empty ${target_file}"
    fi
}

_sync_dir_from_mount() {
    local source_dir="$1"
    local target_dir="$2"
    local config_name="$3"

    if [ -d "${source_dir}" ]; then
        mkdir -p "${target_dir}" 2>/dev/null || true
        cp -a "${source_dir}/." "${target_dir}/" 2>/dev/null || true
        echo "✅ ${config_name} synchronized to ${target_dir}"
    elif [ ! -d "${target_dir}" ]; then
        mkdir -p "${target_dir}" 2>/dev/null || true
        echo "ℹ️  ${config_name} mount source not found, created ${target_dir}"
    fi
}

_ensure_config_files() {
    local target_dir="$1"
    
    # Ensure directories exist
    mkdir -p "${target_dir}/.ssh" 2>/dev/null || true
    mkdir -p "${target_dir}/.gnupg" 2>/dev/null || true
    chmod 700 "${target_dir}/.ssh" 2>/dev/null || true
    chmod 700 "${target_dir}/.gnupg" 2>/dev/null || true
    
    # Ensure regular files exist (empty if not mounted)
    touch "${target_dir}/.gitconfig" 2>/dev/null || true
    touch "${target_dir}/.npmrc" 2>/dev/null || true
}

mkdir -p "${TARGET_HOME}" 2>/dev/null || true

_sync_file_from_mount "${SOURCE_HOME}/.gitconfig" "${TARGET_HOME}/.gitconfig" ".gitconfig"
_sync_dir_from_mount "${SOURCE_HOME}/.ssh" "${TARGET_HOME}/.ssh" ".ssh"
_sync_dir_from_mount "${SOURCE_HOME}/.gnupg" "${TARGET_HOME}/.gnupg" ".gnupg"
_sync_file_from_mount "${SOURCE_HOME}/.npmrc" "${TARGET_HOME}/.npmrc" ".npmrc"

_ensure_config_files "${TARGET_HOME}"

# Best effort ownership fix for target user
if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" "${TARGET_HOME}/.ssh" "${TARGET_HOME}/.gnupg" "${TARGET_HOME}/.gitconfig" "${TARGET_HOME}/.npmrc" 2>/dev/null || true
fi

# ============================================================================
# VERIFY: Check what was actually mounted vs what's empty
# ============================================================================

_check_mount_status() {
    local target_dir="$1"
    local config_file="$2"
    local config_name="$3"
    
    if [ ! -f "${target_dir}/${config_file}" ]; then
        echo "⚠️  ${config_name} not found - creating empty"
        touch "${target_dir}/${config_file}" 2>/dev/null || true
        return 1
    fi
    
    # Check if file is empty (likely mount failed)
    if [ ! -s "${target_dir}/${config_file}" ]; then
        echo "⚠️  ${config_name} is empty (mount may have failed)"
        return 1
    fi
    
    echo "✅ ${config_name} is present and has content"
    return 0
}

echo "📋 Verifying configuration file mounts:"
echo ""

_check_mount_status "${TARGET_HOME}" ".npmrc" ".npmrc" || true
_check_mount_status "${TARGET_HOME}" ".gitconfig" ".gitconfig" || true
[ -d "${TARGET_HOME}/.ssh" ] && echo "✅ .ssh directory exists" || echo "⚠️  .ssh directory not found"
[ -d "${TARGET_HOME}/.gnupg" ] && echo "✅ .gnupg directory exists" || echo "⚠️  .gnupg directory not found"

echo ""

# Test SSH agent forwarding
STABLE_SSH_AGENT_SOCKET="${SOURCE_HOME}/.ssh/agent.sock"

if [ -S "$STABLE_SSH_AGENT_SOCKET" ]; then
    export SSH_AUTH_SOCK="$STABLE_SSH_AGENT_SOCKET"
    echo "✅ SSH agent forwarding is working (stable socket: $SSH_AUTH_SOCK)"
    if command -v ssh-add >/dev/null 2>&1; then
        if ssh-add -l >/dev/null 2>&1; then
            KEY_COUNT=$(ssh-add -l 2>/dev/null | wc -l)
            echo "   - ${KEY_COUNT} SSH key(s) loaded"
        else
            echo "   - No SSH keys loaded in agent"
        fi
    fi
elif [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    echo "✅ SSH agent forwarding is working"
elif [ -S "/ssh-agent" ]; then
    # Backward compatibility if an external config still mounts /ssh-agent
    export SSH_AUTH_SOCK="/ssh-agent"
    echo "✅ SSH agent forwarding is working (legacy socket: $SSH_AUTH_SOCK)"
elif [ -d "${TARGET_HOME}/.ssh" ]; then
    echo "✅ SSH keys directory available at ${TARGET_HOME}/.ssh"
    if [ -f "${TARGET_HOME}/.ssh/id_rsa" ] || [ -f "${TARGET_HOME}/.ssh/id_ed25519" ]; then
        echo "   - SSH keys detected"
    fi
else
    echo "ℹ️  No SSH configuration detected (optional)"
fi

# Test GPG setup
if command -v gpg >/dev/null 2>&1; then
    if [ -d "${TARGET_HOME}/.gnupg" ]; then
        if gpg --list-secret-keys >/dev/null 2>&1; then
            GPG_KEYS=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep -c "^sec" || echo "0")
            echo "✅ GPG configured (${GPG_KEYS} secret key(s) found)"
        else
            echo "ℹ️  GPG mounted but no secret keys"
        fi
    else
        echo "ℹ️  GPG directory not available (optional for commit signing)"
    fi
else
    echo "ℹ️  GPG not installed"
fi

# Special check for .npmrc - this is the critical one
echo ""
if [ -f "${TARGET_HOME}/.npmrc" ] && [ -s "${TARGET_HOME}/.npmrc" ]; then
    echo "✅ npm configuration (.npmrc) mounted with content"
    if grep -qE "(authToken|_auth|//.*:_)" "${TARGET_HOME}/.npmrc" 2>/dev/null; then
        echo "   - Authentication tokens are configured"
    else
        echo "   - No tokens configured (public registries only)"
    fi
elif [ -f "${TARGET_HOME}/.npmrc" ]; then
    echo "⚠️  npm configuration (.npmrc) exists but is empty"
    echo "   - This might indicate the mount failed or source file was empty"
    echo "   - Configure tokens in ~/.npmrc on your host machine"
else
    echo "⚠️  npm configuration (.npmrc) not found"
    echo "   ➜ Edit ~/.npmrc on your host machine to add authentication tokens"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Local development files mount verification complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Configuration Summary:"
echo "   Git config  → ${TARGET_HOME}/.gitconfig"
echo "   SSH keys    → ${TARGET_HOME}/.ssh"
echo "   GPG keys    → ${TARGET_HOME}/.gnupg"
echo "   npm tokens  → ${TARGET_HOME}/.npmrc"
echo "   SSH agent   → ${STABLE_SSH_AGENT_SOCKET}"
echo ""
echo "🔧 To troubleshoot mount issues:"
echo "   1. Check host files exist: ls -la ~/{.npmrc,.gitconfig,.ssh,.gnupg}"
echo "   2. Verify mount points:   ls -la ${TARGET_HOME}/"
echo "   3. Compare file contents: diff ~/.npmrc ${TARGET_HOME}/.npmrc"
echo "   - ~/.npmrc     → ${TARGET_HOME}/.npmrc"
