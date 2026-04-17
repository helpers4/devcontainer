#!/bin/bash

# Test script for dotfiles-sync feature
# Copyright (c) 2025 helpers4
# Licensed under LGPL-3.0 - see LICENSE file for details

set -e

echo "Testing dotfiles-sync feature..."

# Test 1: GPG_TTY env var is set
if [ -n "$GPG_TTY" ]; then
    echo "PASS: GPG_TTY environment variable is set: $GPG_TTY"
else
    echo "WARN: GPG_TTY environment variable not set"
fi

# Test 2: git is available
if command -v git >/dev/null 2>&1; then
    echo "PASS: Git is available"
else
    echo "FAIL: Git is not available"
    exit 1
fi

# Test 3: Directory structure was created at build time
TARGET_HOME="${HOME:-/home/node}"
echo "Checking directory structure at ${TARGET_HOME}..."

for dir in ".ssh" ".gnupg"; do
    if [ -d "${TARGET_HOME}/${dir}" ]; then
        echo "PASS: ${dir} directory exists"
        PERMS=$(stat -c "%a" "${TARGET_HOME}/${dir}" 2>/dev/null || stat -f "%OLp" "${TARGET_HOME}/${dir}" 2>/dev/null)
        if [ "$PERMS" = "700" ]; then
            echo "   Permissions correct (700)"
        else
            echo "   WARN: Permissions: ${PERMS} (expected 700)"
        fi
    else
        echo "FAIL: ${dir} directory not found"
        exit 1
    fi
done

for file in ".gitconfig" ".npmrc"; do
    if [ -f "${TARGET_HOME}/${file}" ]; then
        echo "PASS: ${file} exists"
    else
        echo "FAIL: ${file} not found"
        exit 1
    fi
done

# Test 4: Sync script is installed and executable
SYNC_SCRIPT="/usr/local/share/dotfiles-sync/sync-files.sh"
if [ -x "$SYNC_SCRIPT" ]; then
    echo "PASS: Sync script installed at ${SYNC_SCRIPT}"
else
    echo "FAIL: Sync script not found or not executable at ${SYNC_SCRIPT}"
    exit 1
fi

# Test 5: Config file exists with valid content
CONFIG_FILE="/usr/local/share/dotfiles-sync/config"
if [ -f "$CONFIG_FILE" ]; then
    echo "PASS: Config file exists at ${CONFIG_FILE}"
    if grep -q "DOTFILES_SYNC_USERNAME=" "$CONFIG_FILE" && \
       grep -q "DOTFILES_SYNC_SOURCE=" "$CONFIG_FILE" && \
       grep -q "DOTFILES_SYNC_TARGET=" "$CONFIG_FILE"; then
        echo "   Config contains expected variables"
    else
        echo "FAIL: Config missing expected variables"
        exit 1
    fi
else
    echo "FAIL: Config file not found at ${CONFIG_FILE}"
    exit 1
fi

# Test 6: SSH agent runtime detection script exists
PROFILE_SSH="/etc/profile.d/dotfiles-sync-ssh.sh"
if [ -f "$PROFILE_SSH" ]; then
    echo "PASS: SSH agent detection script installed at ${PROFILE_SSH}"
else
    echo "FAIL: SSH agent detection script not found at ${PROFILE_SSH}"
    exit 1
fi

# Test 7: Sync fallback script exists
PROFILE_SYNC="/etc/profile.d/dotfiles-sync-sync.sh"
if [ -f "$PROFILE_SYNC" ]; then
    echo "PASS: Sync fallback script installed at ${PROFILE_SYNC}"
else
    echo "FAIL: Sync fallback script not found at ${PROFILE_SYNC}"
    exit 1
fi

# Test 8: Sync script runs without error (no mount data in test env)
echo "Running sync script (no mount data expected in test)..."
if "${SYNC_SCRIPT}" 2>&1; then
    echo "PASS: Sync script runs without error"
else
    echo "WARN: Sync script exited with non-zero (may be expected in test environment)"
fi

# Test 9: SSH agent socket (informational)
if [ -n "$SSH_AUTH_SOCK" ]; then
    echo "INFO: SSH_AUTH_SOCK is set to: $SSH_AUTH_SOCK"
    if [ -S "$SSH_AUTH_SOCK" ]; then
        echo "PASS: SSH_AUTH_SOCK points to a valid socket"
    else
        echo "WARN: SSH_AUTH_SOCK is set but is not a valid socket"
    fi
else
    echo "INFO: SSH_AUTH_SOCK not set (resolved at shell startup via profile.d)"
fi

echo ""
echo "dotfiles-sync feature test complete!"
