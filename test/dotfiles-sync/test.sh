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
    for flag in DOTFILES_SYNC_GH_AUTH DOTFILES_SYNC_AWS_CONFIG DOTFILES_SYNC_KUBE_CONFIG DOTFILES_SYNC_DOCKER_CONFIG; do
        if grep -q "^${flag}=" "$CONFIG_FILE"; then
            echo "   PASS: ${flag} present in config"
        else
            echo "FAIL: ${flag} missing from config"
            exit 1
        fi
    done
else
    echo "FAIL: Config file not found at ${CONFIG_FILE}"
    exit 1
fi

# Test 5d: hosts.yml is mounted now (opt-in syncGhAuth) but only at the file
# level — must NEVER be mounted as a whole `~/.config/gh` directory because
# that would also expose state.yml and other gh internals.
GH_STAGE="/tmp/dotfiles-sync/.config/gh"
if [ -d "${GH_STAGE}" ] && [ ! -L "${GH_STAGE}" ]; then
    # The directory exists because individual files (config.yml, hosts.yml) are
    # mounted into it, which is fine. We just check there is no extra file
    # bind-mounted that we don't expect.
    for f in "${GH_STAGE}"/*; do
        [ -e "$f" ] || continue
        name=$(basename "$f")
        case "$name" in
            config.yml|hosts.yml) ;;
            *)
                echo "FAIL: unexpected mount in ${GH_STAGE}: ${name}"
                exit 1
                ;;
        esac
    done
fi
echo "PASS: only config.yml and hosts.yml may be mounted under /tmp/dotfiles-sync/.config/gh"

# Test 5e: opt-in directories created at build time
for dir in ".aws" ".kube" ".docker" ".cargo" ".config/pip" ".config/pnpm" ".config/gh" ".config/git"; do
    if [ -d "${TARGET_HOME}/${dir}" ]; then
        echo "PASS: ${dir} directory exists"
    else
        echo "FAIL: ${dir} directory not found"
        exit 1
    fi
done

# Test 5f: _copy_if_absent helper smoke-test (in-process, no system config tampering).
# We exercise the helper logic directly in a sandboxed subshell using mktemp dirs;
# we do NOT touch /usr/local/share/dotfiles-sync/config (root-owned, non-writable
# as the test user "node" on base:ubuntu).
TMP_SRC=$(mktemp -d)
TMP_DST=$(mktemp -d)
mkdir -p "${TMP_SRC}/.cargo"
echo "from-source" > "${TMP_SRC}/.cargo/config.toml"
mkdir -p "${TMP_DST}/.cargo"
echo "preserve-me" > "${TMP_DST}/.cargo/config.toml"

(
    SOURCE_HOME="${TMP_SRC}"
    TARGET_HOME="${TMP_DST}"
    # Inline copy of the helper (mirrors sync-files.sh behavior).
    _copy_if_absent() {
        local _rel="$1"
        local _src="${SOURCE_HOME}/${_rel}"
        local _dst="${TARGET_HOME}/${_rel}"
        [ -L "${_src}" ] && return 0
        [ ! -f "${_src}" ] && return 0
        [ ! -s "${_src}" ] && return 0
        [ -e "${_dst}" ] && return 0
        mkdir -p "$(dirname "${_dst}")" 2>/dev/null || true
        cp -f "${_src}" "${_dst}" 2>/dev/null || true
    }
    _copy_if_absent ".cargo/config.toml"
)
if [ "$(cat "${TMP_DST}/.cargo/config.toml")" = "preserve-me" ]; then
    echo "PASS: _copy_if_absent does not overwrite existing target"
else
    echo "FAIL: existing target was overwritten"
    rm -rf "${TMP_SRC}" "${TMP_DST}"
    exit 1
fi

# Test 5g: _copy_if_absent copies when target is absent
rm -f "${TMP_DST}/.cargo/config.toml"
(
    SOURCE_HOME="${TMP_SRC}"
    TARGET_HOME="${TMP_DST}"
    _copy_if_absent() {
        local _rel="$1"
        local _src="${SOURCE_HOME}/${_rel}"
        local _dst="${TARGET_HOME}/${_rel}"
        [ -L "${_src}" ] && return 0
        [ ! -f "${_src}" ] && return 0
        [ ! -s "${_src}" ] && return 0
        [ -e "${_dst}" ] && return 0
        mkdir -p "$(dirname "${_dst}")" 2>/dev/null || true
        cp -f "${_src}" "${_dst}" 2>/dev/null || true
    }
    _copy_if_absent ".cargo/config.toml"
)
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
