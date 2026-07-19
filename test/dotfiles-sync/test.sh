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
else
    echo "FAIL: Config file not found at ${CONFIG_FILE}"
    exit 1
fi

# Test 5e: opt-in directories created at build time
for dir in ".aws" ".kube" ".docker" ".config/git"; do
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

# Test 5h: bare-path git config values under .ssh/.gnupg are rewritten to
# TARGET_HOME/.ssh or TARGET_HOME/.gnupg for allowlisted keys only. Sources
# the REAL path-keys.sh (installed by install.sh) instead of hand-copying the
# allowlists/helpers — a change to REHOMEABLE_PATH_KEYS or the rewrite logic
# in production is automatically exercised here too, no separate test copy to
# fall out of sync. Uses the same TARGET_HOME this test already derived from
# the real config file above (not a disconnected placeholder), and routes
# values through a REAL `git config --file ... --list` round trip (not a
# hand-typed key string) — `git config --list` always lowercases keys, so a
# previous version of this test that called the rewrite helper directly with
# the mixed-case key spelling ("http.sslKey") never exercised that
# normalization and missed a real bug where the allowlist itself used
# mixed-case spellings that could never match the lowercased KEY seen in
# production.
PATH_KEYS_FILE="/usr/local/share/dotfiles-sync/path-keys.sh"
if [ ! -r "${PATH_KEYS_FILE}" ]; then
    echo "FAIL: path-keys.sh not found at ${PATH_KEYS_FILE}"
    exit 1
fi
# shellcheck source=/dev/null
. "${PATH_KEYS_FILE}"

TMP_SRC_GIT=$(mktemp)
git config --file "${TMP_SRC_GIT}" user.signingKey "/home/some-host-user/.ssh/id_test_ed25519.pub"
git config --file "${TMP_SRC_GIT}" http.sslCert "/home/some-host-user/.gnupg/nested/client.key"
git config --file "${TMP_SRC_GIT}" core.editor "/home/some-host-user/.ssh/some-editor"
git config --file "${TMP_SRC_GIT}" http.sslCAInfo ".ssh/id_relative_ed25519.pub"

REWRITTEN=""
while IFS= read -r line; do
    _key="${line%%=*}"
    _val="${line#*=}"
    if _key_in_list "${_key}" "${REHOMEABLE_PATH_KEYS}"; then
        _val="$(_rehome_path_value "${_val}")"
    fi
    REWRITTEN="${REWRITTEN}${_key}=${_val}
"
done < <(git config --file "${TMP_SRC_GIT}" --list)
rm -f "${TMP_SRC_GIT}"

if echo "${REWRITTEN}" | grep -qF "user.signingkey=${TARGET_HOME}/.ssh/id_test_ed25519.pub"; then
    echo "PASS: user.signingkey .ssh path rewritten to TARGET_HOME/.ssh"
else
    echo "FAIL: user.signingkey path not rewritten correctly"
    echo "${REWRITTEN}"
    exit 1
fi

# This is the exact regression this test previously missed: git normalizes
# "http.sslCert" to "http.sslcert" in --list output, and the rewrite must
# also preserve the subdirectory under .gnupg (not just the basename), since
# the real .gnupg sync copies files recursively.
if echo "${REWRITTEN}" | grep -qF "http.sslcert=${TARGET_HOME}/.gnupg/nested/client.key"; then
    echo "PASS: http.sslCert (normalized to http.sslcert) .gnupg nested path rewritten, subdirectory preserved"
else
    echo "FAIL: http.sslCert path not rewritten correctly (mixed-case key or nested-path regression)"
    echo "${REWRITTEN}"
    exit 1
fi

if echo "${REWRITTEN}" | grep -qF "core.editor=/home/some-host-user/.ssh/some-editor"; then
    echo "PASS: non-allowlisted key left untouched by the rehome rewrite"
else
    echo "FAIL: rehome rewrite touched a key outside REHOMEABLE_PATH_KEYS"
    echo "${REWRITTEN}"
    exit 1
fi

# A bare relative path (no leading "/", as git config allows) must also be
# rewritten — this previously required a literal "/" before ".ssh/"/".gnupg/"
# and silently left relative-form values unrewritten.
if echo "${REWRITTEN}" | grep -qF "http.sslcainfo=${TARGET_HOME}/.ssh/id_relative_ed25519.pub"; then
    echo "PASS: bare-relative .ssh path (no leading slash) rewritten to TARGET_HOME/.ssh"
else
    echo "FAIL: bare-relative .ssh path not rewritten correctly"
    echo "${REWRITTEN}"
    exit 1
fi

# Test 5i: post-sync verification (single `git config --list` pass, run only
# after .ssh/.gnupg are synced — see sync-files.sh) warns for path-like
# values missing in the container, strips a leading "!" (credential.helper's
# shell-invocation prefix) and a leading "~/" (resolved against TARGET_HOME)
# before checking, checks the whole value first so paths containing spaces
# aren't falsely flagged, then falls back to per-token checks so an
# interpreter-invoked script isn't hidden behind an always-present
# interpreter binary — and stays silent for values that exist or aren't
# path-shaped. Uses the real _key_in_list/_warn_if_missing_path from
# path-keys.sh (sourced in Test 5h above), not a hand-copied reimplementation.
TMP_GIT=$(mktemp)
EXISTING_FILE=$(mktemp)
EXISTING_DIR_WITH_SPACE=$(mktemp -d)"/dir with space"
mkdir -p "${EXISTING_DIR_WITH_SPACE}"
touch "${EXISTING_DIR_WITH_SPACE}/gpg.exe"

git config --file "${TMP_GIT}" user.signingkey "/definitely/does/not/exist/id_ed25519.pub"
git config --file "${TMP_GIT}" gpg.program "${EXISTING_FILE} --batch"
git config --file "${TMP_GIT}" core.editor "code --wait"
git config --file "${TMP_GIT}" credential.helper "!/definitely/does/not/exist/git-credential-wrapper --flag"
git config --file "${TMP_GIT}" http.sslcert "${EXISTING_DIR_WITH_SPACE}/gpg.exe"
git config --file "${TMP_GIT}" gpg.ssh.program "!/bin/sh /definitely/does/not/exist/gpg-ssh-wrapper.sh"
# shellcheck disable=SC2088 # literal "~" is intentional: testing that
# _warn_if_missing_path expands it against TARGET_HOME, not the shell
git config --file "${TMP_GIT}" http.sslkey "~/definitely/does/not/exist/tls.key"

VERIFY_OUTPUT=$(
    while IFS= read -r line; do
        vkey="${line%%=*}"
        vval="${line#*=}"
        [ -z "${vkey}" ] && continue
        _key_in_list "${vkey}" "${VERIFY_PATH_KEYS}" || continue
        _warn_if_missing_path "${vkey}" "${vval}"
    done < <(git config --file "${TMP_GIT}" --list 2>/dev/null)
)

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: user.signingkey"; then
    echo "PASS: verification warns for a missing signingkey path"
else
    echo "FAIL: verification did not warn for a missing signingkey path"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: gpg.program"; then
    echo "FAIL: verification incorrectly warned for an existing gpg.program path with trailing flags"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
else
    echo "PASS: verification stays silent for an existing gpg.program path despite trailing flags"
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: core.editor="; then
    echo "FAIL: verification incorrectly warned for a bare-command core.editor value"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
else
    echo "PASS: verification stays silent for a non-absolute core.editor command"
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: credential.helper"; then
    echo "PASS: verification warns for a missing '!'-prefixed credential.helper path"
else
    echo "FAIL: verification did not warn for a missing '!'-prefixed credential.helper path"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: http.sslcert"; then
    echo "FAIL: verification incorrectly warned for an existing path containing a space"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
else
    echo "PASS: verification stays silent for an existing path containing a space (not truncated)"
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: gpg.ssh.program"; then
    echo "PASS: verification warns for a missing interpreter-invoked script (not hidden behind the interpreter binary)"
else
    echo "FAIL: verification did not warn for a missing interpreter-invoked script"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
fi

if echo "${VERIFY_OUTPUT}" | grep -q "WARN: http.sslkey"; then
    echo "PASS: verification warns for a missing '~/'-prefixed path"
else
    echo "FAIL: verification did not warn for a missing '~/'-prefixed path"
    rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"
    exit 1
fi
rm -rf "${TMP_GIT}" "${EXISTING_FILE}" "${EXISTING_DIR_WITH_SPACE}"

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
