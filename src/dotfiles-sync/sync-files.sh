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
#                  Host-specific path values that don't survive the merge
#                  verbatim (user.signingkey, credential.helper, gpg.program,
#                  ...) are NOT rewritten here — that's helpers4-common's
#                  git-config-self-heal.sh (postAttachCommand), which actively
#                  fixes them at attach time regardless of whether dotfiles-sync
#                  is even in use.
#   .npmrc      -> merge line-by-line (key=value): source entries appended only
#                  when the key is absent from the target.
#   .ssh/config -> merge Host blocks: source blocks appended when Host absent.
#   .ssh keys   -> copy only when destination file does not exist yet, and only
#                  when syncSshKeys is enabled (default: off — private key
#                  material never touches the container filesystem unless
#                  explicitly opted in; SSH auth normally works fine through
#                  the client's own forwarded ssh-agent with no local file at
#                  all). .ssh/config and known_hosts always sync regardless —
#                  agent forwarding doesn't provide either of those.
#   .gnupg      -> skipped on cloud environments (GPG handled natively there).
#   known_hosts -> merge line-by-line (append missing host entries).
#   ── extra files (v1.0.1+) — copy-if-absent strategy:
#   .config/git/{ignore,attributes,config-*}, .yarnrc.yml
#   .aws/config                -> opt-in (DOTFILES_SYNC_AWS_CONFIG)
#   .kube/config               -> opt-in (DOTFILES_SYNC_KUBE_CONFIG)
#   .docker/config.json        -> opt-in (DOTFILES_SYNC_DOCKER_CONFIG)
#
# No set -e: sync as much as possible even if one part fails.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config"

if [ ! -r "${CONFIG_FILE}" ]; then
    echo "dotfiles-sync: config file ${CONFIG_FILE} not found or not readable, aborting sync"
    exit 1
fi

# shellcheck source=/dev/null
. "${CONFIG_FILE}"

# h4_detect_cloud_env comes from helpers4-common (dependsOn) — shared with
# helpers4-common's own git-config-self-heal.sh so the two can't silently
# disagree on what counts as a cloud environment.
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

USERNAME="${DOTFILES_SYNC_USERNAME}"
SOURCE_HOME="${DOTFILES_SYNC_SOURCE}"
TARGET_HOME="${DOTFILES_SYNC_TARGET}"
SYNC_AWS_CONFIG="${DOTFILES_SYNC_AWS_CONFIG:-false}"
SYNC_KUBE_CONFIG="${DOTFILES_SYNC_KUBE_CONFIG:-false}"
SYNC_DOCKER_CONFIG="${DOTFILES_SYNC_DOCKER_CONFIG:-false}"
SYNC_SSH_KEYS="${DOTFILES_SYNC_SSH_KEYS:-false}"

if [ -z "${USERNAME}" ] || [ -z "${SOURCE_HOME}" ] || [ -z "${TARGET_HOME}" ]; then
    echo "dotfiles-sync: config is missing required values, aborting sync"
    exit 1
fi

# ── Environment detection ─────────────────────────────────────────────────────
# IS_CLOUD_ENV=true means: the platform manages git auth and GPG signing.
# In that case we use a stricter merge (more protected keys, skip .gnupg).

h4_detect_cloud_env

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
HAS_GIT=false
command -v git >/dev/null 2>&1 && HAS_GIT=true

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

# Membership test for a space-separated allowlist string (e.g. PROTECTED_KEYS).
# Args: <needle> <space-separated list>
_key_in_list() {
    local _needle="$1" _item
    for _item in ${2}; do
        [ "${_needle}" = "${_item}" ] && return 0
    done
    return 1
}

# ── Merge .gitconfig ──────────────────────────────────────────────────────────

if [ -L "${SOURCE_HOME}/.gitconfig" ]; then
    echo "   .gitconfig: symlink, skipping for security"
elif [ -f "${SOURCE_HOME}/.gitconfig" ] && [ -s "${SOURCE_HOME}/.gitconfig" ]; then
    TARGET_GIT="${TARGET_HOME}/.gitconfig"
    touch "${TARGET_GIT}" 2>/dev/null || true
    chmod 600 "${TARGET_GIT}" 2>/dev/null || true

    if [ "${HAS_GIT}" = "true" ]; then
        # Smart merge via git config
        PROTECTED_KEYS="credential.helper user.name user.email user.signingkey gpg.program gpg.format commit.gpgsign tag.gpgsign"

        MERGED=0
        SKIPPED=0
        while IFS= read -r line; do
            KEY="${line%%=*}"
            VAL="${line#*=}"
            [ -z "${KEY}" ] && continue

            existing="$(_gitconfig_get "${TARGET_GIT}" "${KEY}")"

            # On cloud envs: skip protected keys if already present
            if [ "${IS_CLOUD_ENV}" = "true" ] && [ -n "${existing}" ] && \
                    _key_in_list "${KEY}" "${PROTECTED_KEYS}"; then
                SKIPPED=$((SKIPPED + 1))
                continue
            fi

            # Merge: only set if not already present
            if [ -z "${existing}" ]; then
                _gitconfig_set "${TARGET_GIT}" "${KEY}" "${VAL}"
                MERGED=$((MERGED + 1))
            fi
        done < <(git config --file "${SOURCE_HOME}/.gitconfig" --list 2>/dev/null)

        echo "   .gitconfig: merged (${MERGED} added, ${SKIPPED} protected)"
    else
        # Fallback without git: copy source if target is empty
        if [ ! -s "${TARGET_GIT}" ]; then
            cp -f "${SOURCE_HOME}/.gitconfig" "${TARGET_GIT}"
            echo "   .gitconfig: copied (git not available for merge)"
        else
            echo "   .gitconfig: skipped (target not empty, git not available for merge)"
        fi
    fi
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

    # Key files (private and public) — opt-in only. SSH auth normally works
    # fine through the client's own forwarded ssh-agent with no local key
    # file at all; copying them puts private key material on the container's
    # filesystem, which most setups relying on agent forwarding deliberately
    # avoid. .ssh/config and known_hosts below are unconditional — the agent
    # doesn't provide either of those.
    if [ "${SYNC_SSH_KEYS}" = "true" ]; then
        find "${SOURCE_HOME}/.ssh" -maxdepth 1 -type f ! -name "config" ! -name "known_hosts" \
            | while IFS= read -r src_file; do
            fname="$(basename "${src_file}")"
            dest="${TARGET_HOME}/.ssh/${fname}"
            if [ ! -f "${dest}" ]; then
                cp -f "${src_file}" "${dest}"
            fi
        done
    fi

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
    if [ "${SYNC_SSH_KEYS}" = "true" ]; then
        echo "   .ssh: merged (${FILE_COUNT} files total)"
    else
        echo "   .ssh: config/known_hosts merged (${FILE_COUNT} files total); key files skipped (opt-in: set 'syncSshKeys' to enable)"
    fi
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

# Path-like .gitconfig values (user.signingkey, credential.helper, ...) are
# no longer verified/warned about here — helpers4-common's
# git-config-self-heal.sh actively fixes them instead, on every attach,
# whether or not dotfiles-sync ran at all.

# ── Helper: copy-if-absent ────────────────────────────────────────────────────
# Copies a single source file to target only if target does not already exist.
# Skips symlinks (security), empty files, and missing sources.
# Args: <relative_path> <label> [optional_chmod]
_copy_if_absent() {
    local _rel="$1" _label="$2" _mode="${3:-}"
    local _src="${SOURCE_HOME}/${_rel}"
    local _dst="${TARGET_HOME}/${_rel}"

    if [ -L "${_src}" ]; then
        echo "   ${_label}: symlink in staging, skipping for security"
        return 0
    fi
    if [ ! -f "${_src}" ] || [ ! -s "${_src}" ]; then
        echo "   ${_label}: not found or empty in staging"
        return 0
    fi
    if [ -e "${_dst}" ]; then
        echo "   ${_label}: target already exists, skipping (no overwrite)"
        return 0
    fi

    mkdir -p "$(dirname "${_dst}")" 2>/dev/null || true
    if cp -f "${_src}" "${_dst}" 2>/dev/null; then
        [ -n "${_mode}" ] && chmod "${_mode}" "${_dst}" 2>/dev/null || true
        echo "   ${_label}: copied"
    else
        echo "   ${_label}: copy failed"
    fi
}


# ── Sync ~/.config/git/{ignore,attributes,config-*} ───────────────────────────
if [ -d "${SOURCE_HOME}/.config/git" ]; then
    mkdir -p "${TARGET_HOME}/.config/git"
    _copy_if_absent ".config/git/ignore"     ".config/git/ignore"     "644"
    _copy_if_absent ".config/git/attributes" ".config/git/attributes" "644"
    # Optional modular includes (config-*, e.g. config-work, config-perso)
    find "${SOURCE_HOME}/.config/git" -maxdepth 1 -type f -name 'config-*' \
        2>/dev/null | while IFS= read -r _src; do
        _name="$(basename "${_src}")"
        _copy_if_absent ".config/git/${_name}" ".config/git/${_name}" "644"
    done
else
    echo "   .config/git: not found in staging"
fi

# ── Sync ~/.yarnrc.yml ────────────────────────────────────────────────────────
_copy_if_absent ".yarnrc.yml" ".yarnrc.yml" "644"

# ── Sync ~/.aws/config (opt-in) ───────────────────────────────────────────────
if [ "${SYNC_AWS_CONFIG}" = "true" ]; then
    mkdir -p "${TARGET_HOME}/.aws"
    _copy_if_absent ".aws/config" ".aws/config" "600"
else
    echo "   .aws/config: skipped (opt-in: set 'syncAwsConfig' to enable)"
fi

# ── Sync ~/.kube/config (opt-in) ──────────────────────────────────────────────
if [ "${SYNC_KUBE_CONFIG}" = "true" ]; then
    if [ "${IS_CLOUD_ENV}" = "true" ]; then
        echo "   .kube/config: skipped (cloud env — use platform-native cluster access)"
    else
        mkdir -p "${TARGET_HOME}/.kube"
        _copy_if_absent ".kube/config" ".kube/config [cluster credentials]" "600"
    fi
else
    echo "   .kube/config: skipped (opt-in: set 'syncKubeConfig' to enable)"
fi

# ── Sync ~/.docker/config.json (opt-in) ───────────────────────────────────────
if [ "${SYNC_DOCKER_CONFIG}" = "true" ]; then
    if [ "${IS_CLOUD_ENV}" = "true" ]; then
        echo "   .docker/config.json: skipped (cloud env — platform manages registry auth)"
    else
        mkdir -p "${TARGET_HOME}/.docker"
        _copy_if_absent ".docker/config.json" ".docker/config.json [registry tokens]" "600"
    fi
else
    echo "   .docker/config.json: skipped (opt-in: set 'syncDockerConfig' to enable)"
fi

# ── Fix ownership ─────────────────────────────────────────────────────────────

if [ "$(id -u)" -eq 0 ] && getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" \
        "${TARGET_HOME}/.ssh" \
        "${TARGET_HOME}/.gnupg" \
        "${TARGET_HOME}/.gitconfig" \
        "${TARGET_HOME}/.npmrc" \
        "${TARGET_HOME}/.yarnrc.yml" \
        "${TARGET_HOME}/.config" \
        "${TARGET_HOME}/.aws" \
        "${TARGET_HOME}/.kube" \
        "${TARGET_HOME}/.docker" 2>/dev/null || true
fi

# Signal sync completed (used by profile.d fallback)
touch /mnt/h4dotfiles/.synced 2>/dev/null || true

echo "dotfiles-sync: sync complete"
