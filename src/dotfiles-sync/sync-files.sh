#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runtime file sync for dotfiles-sync feature.
# Runs at container start (postStartCommand) when bind mounts are available.
# Also called by profile.d fallback on first shell if postStartCommand missed.
#
# Merge strategy (safe on local, WSL, macOS, Codespaces, Gitpod, DevPod):
#   .gitconfig  -> merge via `git config`: source keys applied only when absent
#                  in target; protected keys (credential.helper, user.*, gpg.*)
#                  never overwritten on cloud environments (managed by platform).
#   .npmrc      -> merge line-by-line (key=value): source entries appended only
#                  when the key is absent from the target.
#   .ssh/config -> merge Host blocks: source blocks appended when Host absent.
#   .ssh keys   -> copy only when destination file does not exist yet.
#   .gnupg      -> skipped on cloud environments (GPG handled natively there).
#   known_hosts -> merge line-by-line (append missing host entries).

# No set -e: sync as much as possible even if one part fails.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config"

if [ ! -r "${CONFIG_FILE}" ]; then
    echo "dotfiles-sync: config file ${CONFIG_FILE} not found or not readable, aborting sync"
    exit 1
fi

# shellcheck source=/dev/null
. "${CONFIG_FILE}"

USERNAME="${DOTFILES_SYNC_USERNAME}"
SOURCE_HOME="${DOTFILES_SYNC_SOURCE}"
TARGET_HOME="${DOTFILES_SYNC_TARGET}"

if [ -z "${USERNAME}" ] || [ -z "${SOURCE_HOME}" ] || [ -z "${TARGET_HOME}" ]; then
    echo "dotfiles-sync: config is missing required values, aborting sync"
    exit 1
fi

# ── Environment detection ─────────────────────────────────────────────────────
# IS_CLOUD_ENV=true means: the platform manages git auth and GPG signing.
# In that case we use a stricter merge (more protected keys, skip .gnupg).

IS_CLOUD_ENV=false
ENV_LABEL="local"

if [ "${CODESPACES}" = "true" ] || [ -n "${CODESPACE_NAME}" ]; then
    IS_CLOUD_ENV=true
    ENV_LABEL="GitHub Codespaces"
elif [ -n "${GITPOD_WORKSPACE_ID}" ] || [ -n "${GITPOD_INSTANCE_ID}" ]; then
    IS_CLOUD_ENV=true
    ENV_LABEL="Gitpod"
elif [ "${DEVPOD}" = "true" ] || [ -n "${DEVPOD_WORKSPACE_ID}" ]; then
    IS_CLOUD_ENV=true
    ENV_LABEL="DevPod"
elif grep -qi "microsoft" /proc/version 2>/dev/null || grep -qi "wsl" /proc/version 2>/dev/null; then
    ENV_LABEL="WSL"
fi

echo "dotfiles-sync: environment detected: ${ENV_LABEL}"

if [ "${IS_CLOUD_ENV}" = "true" ]; then
    echo "dotfiles-sync: cloud env — protected keys preserved, .gnupg skipped"
fi

# ── Staging directory check ───────────────────────────────────────────────────

if [ ! -d "${SOURCE_HOME}" ]; then
    echo "dotfiles-sync: staging directory ${SOURCE_HOME} not found, skipping sync"
    exit 0
fi

echo "dotfiles-sync: syncing from ${SOURCE_HOME} -> ${TARGET_HOME}..."

# ── Helper: run git config as target user ─────────────────────────────────────
_gitconfig_set() {
    local _file="$1" _key="$2" _val="$3"
    if [ "$(id -u)" -eq 0 ] && getent passwd "${USERNAME}" >/dev/null 2>&1; then
        su -s /bin/sh "${USERNAME}" -- \
            git config --file "${_file}" "${_key}" "${_val}" 2>/dev/null || \
            git config --file "${_file}" "${_key}" "${_val}" 2>/dev/null || true
    else
        git config --file "${_file}" "${_key}" "${_val}" 2>/dev/null || true
    fi
}

_gitconfig_get() {
    git config --file "$1" --get "$2" 2>/dev/null || true
}

# ── Merge .gitconfig ──────────────────────────────────────────────────────────

if [ -L "${SOURCE_HOME}/.gitconfig" ]; then
    echo "   .gitconfig: symlink, skipping for security"
elif [ -f "${SOURCE_HOME}/.gitconfig" ] && [ -s "${SOURCE_HOME}/.gitconfig" ]; then
    TARGET_GIT="${TARGET_HOME}/.gitconfig"
    touch "${TARGET_GIT}" 2>/dev/null || true
    chmod 600 "${TARGET_GIT}" 2>/dev/null || true

    # Keys managed by cloud platforms — never overwrite when already set.
    # Covers: git auth (credential.helper), identity (user.*),
    # and GPG signing config (gpg.*, commit.gpgsign) which platforms
    # like Codespaces inject via their own signing proxy.
    PROTECTED_KEYS="credential.helper user.name user.email user.signingkey gpg.program gpg.format commit.gpgsign tag.gpgsign"

    MERGED=0
    SKIPPED=0
    while IFS= read -r line; do
        KEY="${line%%=*}"
        VAL="${line#*=}"
        [ -z "${KEY}" ] && continue

        # On cloud envs: skip protected keys if already present
        if [ "${IS_CLOUD_ENV}" = "true" ]; then
            _protected=false
            for pkey in ${PROTECTED_KEYS}; do
                if [ "${KEY}" = "${pkey}" ]; then
                    existing="$(_gitconfig_get "${TARGET_GIT}" "${KEY}")"
                    if [ -n "${existing}" ]; then
                        _protected=true
                        SKIPPED=$((SKIPPED + 1))
                    fi
                    break
                fi
            done
            [ "${_protected}" = "true" ] && continue
        fi

        # Merge: only set if not already present
        existing="$(_gitconfig_get "${TARGET_GIT}" "${KEY}")"
        if [ -z "${existing}" ]; then
            _gitconfig_set "${TARGET_GIT}" "${KEY}" "${VAL}"
            MERGED=$((MERGED + 1))
        fi
    done < <(git config --file "${SOURCE_HOME}/.gitconfig" --list 2>/dev/null)

    echo "   .gitconfig: merged (${MERGED} added, ${SKIPPED} protected)"
elif [ -f "${SOURCE_HOME}/.gitconfig" ]; then
    echo "   .gitconfig: empty, skipping"
else
    echo "   .gitconfig: not found in staging"
fi

# ── Merge .npmrc ──────────────────────────────────────────────────────────────

if [ -L "${SOURCE_HOME}/.npmrc" ]; then
    echo "   .npmrc: symlink, skipping for security"
elif [ -f "${SOURCE_HOME}/.npmrc" ] && [ -s "${SOURCE_HOME}/.npmrc" ]; then
    TARGET_NPMRC="${TARGET_HOME}/.npmrc"
    touch "${TARGET_NPMRC}" 2>/dev/null || true
    chmod 600 "${TARGET_NPMRC}" 2>/dev/null || true

    MERGED=0
    while IFS= read -r line; do
        case "${line}" in '#'*|'') continue ;; esac
        KEY="${line%%=*}"
        [ -z "${KEY}" ] && continue
        if ! grep -Fq "${KEY}=" "${TARGET_NPMRC}" 2>/dev/null; then
            printf '%s\n' "${line}" >> "${TARGET_NPMRC}"
            MERGED=$((MERGED + 1))
        fi
    done < "${SOURCE_HOME}/.npmrc"

    echo "   .npmrc: merged (${MERGED} new entries)"
elif [ -f "${SOURCE_HOME}/.npmrc" ]; then
    echo "   .npmrc: empty, skipping"
else
    echo "   .npmrc: not found in staging"
fi

# ── Merge .ssh ────────────────────────────────────────────────────────────────

if [ -d "${SOURCE_HOME}/.ssh" ]; then
    mkdir -p "${TARGET_HOME}/.ssh"

    # Copy key files — skip if destination already exists
    find "${SOURCE_HOME}/.ssh" -maxdepth 1 -type f ! -name "config" ! -name "known_hosts" \
        | while IFS= read -r src_file; do
        fname="$(basename "${src_file}")"
        dest="${TARGET_HOME}/.ssh/${fname}"
        if [ ! -f "${dest}" ]; then
            cp -f "${src_file}" "${dest}"
        fi
    done

    # Merge known_hosts (append missing entries)
    if [ -f "${SOURCE_HOME}/.ssh/known_hosts" ]; then
        touch "${TARGET_HOME}/.ssh/known_hosts"
        while IFS= read -r line; do
            [ -z "${line}" ] && continue
            case "${line}" in '#'*) continue ;; esac
            host="${line%% *}"
            if ! grep -Fq "${host} " "${TARGET_HOME}/.ssh/known_hosts" 2>/dev/null; then
                printf '%s\n' "${line}" >> "${TARGET_HOME}/.ssh/known_hosts"
            fi
        done < "${SOURCE_HOME}/.ssh/known_hosts"
    fi

    # Merge .ssh/config (append missing Host blocks)
    if [ -f "${SOURCE_HOME}/.ssh/config" ]; then
        touch "${TARGET_HOME}/.ssh/config"
        CURRENT_HOST=""
        CURRENT_BLOCK=""
        while IFS= read -r line || [ -n "${line}" ]; do
            case "${line}" in
                Host\ *|host\ *)
                    if [ -n "${CURRENT_HOST}" ]; then
                        if ! grep -Fiq "Host ${CURRENT_HOST}" \
                                "${TARGET_HOME}/.ssh/config" 2>/dev/null; then
                            printf '\n%s\n' "${CURRENT_BLOCK}" >> "${TARGET_HOME}/.ssh/config"
                        fi
                    fi
                    CURRENT_HOST="${line#* }"
                    CURRENT_BLOCK="${line}"
                    ;;
                *)
                    if [ -n "${CURRENT_HOST}" ]; then
                        CURRENT_BLOCK="${CURRENT_BLOCK}
${line}"
                    fi
                    ;;
            esac
        done < "${SOURCE_HOME}/.ssh/config"
        if [ -n "${CURRENT_HOST}" ]; then
            if ! grep -Fiq "Host ${CURRENT_HOST}" \
                    "${TARGET_HOME}/.ssh/config" 2>/dev/null; then
                printf '\n%s\n' "${CURRENT_BLOCK}" >> "${TARGET_HOME}/.ssh/config"
            fi
        fi
    fi

    # Fix permissions
    chmod 700 "${TARGET_HOME}/.ssh"
    find "${TARGET_HOME}/.ssh" -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
    find "${TARGET_HOME}/.ssh" -name "*.pub" -exec chmod 644 {} \;
    [ -f "${TARGET_HOME}/.ssh/config" ] && chmod 600 "${TARGET_HOME}/.ssh/config"
    [ -f "${TARGET_HOME}/.ssh/known_hosts" ] && chmod 644 "${TARGET_HOME}/.ssh/known_hosts"

    FILE_COUNT=$(find "${TARGET_HOME}/.ssh" -maxdepth 1 -type f | wc -l)
    echo "   .ssh: merged (${FILE_COUNT} files total)"
else
    echo "   .ssh: not found in staging"
fi

# ── Sync .gnupg ───────────────────────────────────────────────────────────────
# Skipped on cloud environments: Codespaces uses a GitHub-managed GPG proxy
# (/.codespaces/bin/gh-gpgsign), Gitpod has its own signing mechanism.
# Importing local GPG keys would conflict with the platform's native signing.
# On local/WSL, keys are copied normally (non-destructive).

if [ "${IS_CLOUD_ENV}" = "true" ]; then
    echo "   .gnupg: skipped (cloud env — use platform native GPG signing)"
elif [ -d "${SOURCE_HOME}/.gnupg" ]; then
    mkdir -p "${TARGET_HOME}/.gnupg"

    (
        cd "${SOURCE_HOME}/.gnupg" || exit 1
        find . -type d -exec mkdir -p "${TARGET_HOME}/.gnupg/{}" \;
        find . -type f ! -type l | while IFS= read -r f; do
            dest="${TARGET_HOME}/.gnupg/${f}"
            [ ! -f "${dest}" ] && cp -f "${f}" "${dest}"
        done
    )

    find "${TARGET_HOME}/.gnupg" -type d -exec chmod 700 {} \;
    find "${TARGET_HOME}/.gnupg" -type f -exec chmod 600 {} \;

    echo "   .gnupg: merged"
else
    echo "   .gnupg: not found in staging"
fi

# ── Fix ownership ─────────────────────────────────────────────────────────────

if [ "$(id -u)" -eq 0 ] && getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" \
        "${TARGET_HOME}/.ssh" \
        "${TARGET_HOME}/.gnupg" \
        "${TARGET_HOME}/.gitconfig" \
        "${TARGET_HOME}/.npmrc" 2>/dev/null || true
fi

# Signal sync completed (used by profile.d fallback)
touch /tmp/.dotfiles-sync-synced 2>/dev/null || true

echo "dotfiles-sync: sync complete"
