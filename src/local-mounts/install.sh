#!/usr/bin/env bash

# Local Mounts DevContainer Feature
# Copyright (c) 2025 helpers4
# Licensed under AGPL-3.0 - see LICENSE file for details
#
# Mounts local Git, SSH, GPG, and npm configuration files into the devcontainer
# for the 'node' user at /home/node
# This script runs INSIDE the container to verify and fix mounts

set -e

echo "🔧 Setting up local-mounts devcontainer feature..."
echo "📁 Container user: node"
echo "📁 Home directory: /home/node"
echo ""

# ============================================================================
# CRITICAL: Verify mounts worked and create fallbacks if needed
# ============================================================================
# Docker bind mounts may fail silently. This section ensures all
# configuration files exist in /home/node for the 'node' user.

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

_ensure_config_files "/home/node"

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

_check_mount_status "/home/node" ".npmrc" ".npmrc" || true
_check_mount_status "/home/node" ".gitconfig" ".gitconfig" || true
[ -d "/home/node/.ssh" ] && echo "✅ .ssh directory exists" || echo "⚠️  .ssh directory not found"
[ -d "/home/node/.gnupg" ] && echo "✅ .gnupg directory exists" || echo "⚠️  .gnupg directory not found"

echo ""

# Test SSH agent forwarding
if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
    echo "✅ SSH agent forwarding is working"
    if command -v ssh-add >/dev/null 2>&1; then
        if ssh-add -l >/dev/null 2>&1; then
            KEY_COUNT=$(ssh-add -l 2>/dev/null | wc -l)
            echo "   - ${KEY_COUNT} SSH key(s) loaded"
        else
            echo "   - No SSH keys loaded in agent"
        fi
    fi
elif [ -d "/home/node/.ssh" ]; then
    echo "✅ SSH keys directory available at /home/node/.ssh"
    if [ -f "/home/node/.ssh/id_rsa" ] || [ -f "/home/node/.ssh/id_ed25519" ]; then
        echo "   - SSH keys detected"
    fi
else
    echo "ℹ️  No SSH configuration detected (optional)"
fi

# Test GPG setup
if command -v gpg >/dev/null 2>&1; then
    if [ -d "/home/node/.gnupg" ]; then
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
if [ -f "/home/node/.npmrc" ] && [ -s "/home/node/.npmrc" ]; then
    echo "✅ npm configuration (.npmrc) mounted with content"
    if grep -qE "(authToken|_auth|//.*:_)" "/home/node/.npmrc" 2>/dev/null; then
        echo "   - Authentication tokens are configured"
    else
        echo "   - No tokens configured (public registries only)"
    fi
elif [ -f "/home/node/.npmrc" ]; then
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
echo "   Git config  → /home/node/.gitconfig"
echo "   SSH keys    → /home/node/.ssh"
echo "   GPG keys    → /home/node/.gnupg"
echo "   npm tokens  → /home/node/.npmrc"
echo ""
echo "🔧 To troubleshoot mount issues:"
echo "   1. Check host files exist: ls -la ~/{.npmrc,.gitconfig,.ssh,.gnupg}"
echo "   2. Verify mount points:   ls -la /home/node/"
echo "   3. Compare file contents: diff ~/.npmrc /home/node/.npmrc"
echo "   - ~/.npmrc     → ${TARGET_HOME}/.npmrc"
