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

# Test 2: git availability (informational — not required)
if command -v git >/dev/null 2>&1; then
    echo "PASS: Git is available (smart gitconfig merge enabled)"
else
    echo "INFO: Git is not available (gitconfig merge will use copy fallback)"
fi

# Test 3: Directory structure was created at build time
# Read target from the config file written by install.sh (source of truth)
CONFIG_FILE="/usr/local/share/dotfiles-sync/config"
if [ -f "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONFIG_FILE"
    TARGET_HOME="${DOTFILES_SYNC_TARGET}"
fi
TARGET_HOME="${TARGET_HOME:-/home/node}"
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
    # Test 5b: Opt-in flags persisted in config
    for flag in DOTFILES_SYNC_AWS_CONFIG DOTFILES_SYNC_KUBE_CONFIG DOTFILES_SYNC_DOCKER_CONFIG; do
        if grep -q "^${flag}=" "$CONFIG_FILE"; then
            echo "   PASS: ${flag} present in config"
        else
            echo "FAIL: ${flag} missing from config"
            exit 1
        fi
    done
    # Test 5c: removed option must NOT be present anymore (security regression guard)
    if grep -q "^DOTFILES_SYNC_GH_AUTH=" "$CONFIG_FILE"; then
        echo "FAIL: DOTFILES_SYNC_GH_AUTH must not be in config (option removed in 1.2.0)"
        exit 1
    fi
    echo "   PASS: removed DOTFILES_SYNC_GH_AUTH not present"
else
    echo "FAIL: Config file not found at ${CONFIG_FILE}"
    exit 1
fi

# Test 5d: feature.json must NOT mount the gh directory or hosts.yml
FEATURE_JSON_GLOB="/tmp/dotfiles-sync"
if [ -e "${FEATURE_JSON_GLOB}/.config/gh/hosts.yml" ]; then
    echo "FAIL: hosts.yml should never be mounted (security: contains OAuth token)"
    exit 1
fi
echo "PASS: hosts.yml not mounted in /tmp/dotfiles-sync"

# Test 5e: opt-in directories created at build time
for dir in ".aws" ".kube" ".docker" ".cargo" ".config/pip" ".config/pnpm" ".config/gh" ".config/git"; do
    if [ -d "${TARGET_HOME}/${dir}" ]; then
        echo "PASS: ${dir} directory exists"
    else
        echo "FAIL: ${dir} directory not found"
        exit 1
    fi
done

# Test 5f: _copy_if_absent helper does not overwrite existing files
TMP_SRC=$(mktemp -d)
TMP_DST=$(mktemp -d)
mkdir -p "${TMP_SRC}/.cargo"
echo "from-source" > "${TMP_SRC}/.cargo/config.toml"
mkdir -p "${TMP_DST}/.cargo"
echo "preserve-me" > "${TMP_DST}/.cargo/config.toml"
DOTFILES_SYNC_USERNAME="$(id -un)" \
DOTFILES_SYNC_SOURCE="${TMP_SRC}" \
DOTFILES_SYNC_TARGET="${TMP_DST}" \
DOTFILES_SYNC_AWS_CONFIG=false \
DOTFILES_SYNC_KUBE_CONFIG=false \
DOTFILES_SYNC_DOCKER_CONFIG=false \
bash -c '
    SCRIPT_DIR="/usr/local/share/dotfiles-sync"
    cp "$SCRIPT_DIR/config" "$SCRIPT_DIR/config.bak"
    cat > "$SCRIPT_DIR/config" <<EOF
DOTFILES_SYNC_USERNAME="'"$(id -un)"'"
DOTFILES_SYNC_SOURCE="'"${TMP_SRC}"'"
DOTFILES_SYNC_TARGET="'"${TMP_DST}"'"
DOTFILES_SYNC_AWS_CONFIG=false
DOTFILES_SYNC_KUBE_CONFIG=false
DOTFILES_SYNC_DOCKER_CONFIG=false
EOF
    "$SCRIPT_DIR/sync-files.sh" >/dev/null 2>&1 || true
    mv -f "$SCRIPT_DIR/config.bak" "$SCRIPT_DIR/config"
'
if [ "$(cat "${TMP_DST}/.cargo/config.toml")" = "preserve-me" ]; then
    echo "PASS: _copy_if_absent does not overwrite existing target"
else
    echo "FAIL: existing target was overwritten"
    cat "${TMP_DST}/.cargo/config.toml"
    rm -rf "${TMP_SRC}" "${TMP_DST}"
    exit 1
fi

# Test 5g: _copy_if_absent copies when target is absent
rm -f "${TMP_DST}/.cargo/config.toml"
DOTFILES_SYNC_USERNAME="$(id -un)" \
DOTFILES_SYNC_SOURCE="${TMP_SRC}" \
DOTFILES_SYNC_TARGET="${TMP_DST}" \
DOTFILES_SYNC_AWS_CONFIG=false \
DOTFILES_SYNC_KUBE_CONFIG=false \
DOTFILES_SYNC_DOCKER_CONFIG=false \
bash -c '
    SCRIPT_DIR="/usr/local/share/dotfiles-sync"
    cp "$SCRIPT_DIR/config" "$SCRIPT_DIR/config.bak"
    cat > "$SCRIPT_DIR/config" <<EOF
DOTFILES_SYNC_USERNAME="'"$(id -un)"'"
DOTFILES_SYNC_SOURCE="'"${TMP_SRC}"'"
DOTFILES_SYNC_TARGET="'"${TMP_DST}"'"
DOTFILES_SYNC_AWS_CONFIG=false
DOTFILES_SYNC_KUBE_CONFIG=false
DOTFILES_SYNC_DOCKER_CONFIG=false
EOF
    "$SCRIPT_DIR/sync-files.sh" >/dev/null 2>&1 || true
    mv -f "$SCRIPT_DIR/config.bak" "$SCRIPT_DIR/config"
'
if [ "$(cat "${TMP_DST}/.cargo/config.toml" 2>/dev/null)" = "from-source" ]; then
    echo "PASS: _copy_if_absent copies when target is absent"
else
    echo "FAIL: file was not copied"
    rm -rf "${TMP_SRC}" "${TMP_DST}"
    exit 1
fi
rm -rf "${TMP_SRC}" "${TMP_DST}"

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
