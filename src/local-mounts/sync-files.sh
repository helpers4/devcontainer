#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runtime file sync for local-mounts feature.
# Runs at container start (postStartCommand) when bind mounts are available.
# Also called by profile.d fallback on first shell if postStartCommand missed.

# No set -e: sync as much as possible even if one part fails.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config"

if [ ! -r "${CONFIG_FILE}" ]; then
    echo "❌ local-mounts: config file ${CONFIG_FILE} not found or not readable, aborting sync"
    exit 1
fi

# shellcheck source=/dev/null
. "${CONFIG_FILE}"

USERNAME="${LOCAL_MOUNTS_USERNAME}"
SOURCE_HOME="${LOCAL_MOUNTS_SOURCE}"
TARGET_HOME="${LOCAL_MOUNTS_TARGET}"

if [ -z "${USERNAME}" ] || [ -z "${SOURCE_HOME}" ] || [ -z "${TARGET_HOME}" ]; then
    echo "❌ local-mounts: config is missing required values, aborting sync"
    exit 1
fi

# Check staging directory exists (bind mounts active?)
if [ ! -d "${SOURCE_HOME}" ]; then
    echo "ℹ️  local-mounts: staging directory ${SOURCE_HOME} not found, skipping sync"
    exit 0
fi

echo "🔧 local-mounts: syncing files from ${SOURCE_HOME} to ${TARGET_HOME}..."

# ── Sync .gitconfig ──────────────────────────────────────────────────────────

if [ -L "${SOURCE_HOME}/.gitconfig" ]; then
    echo "   ⚠️  .gitconfig is a symlink, skipping for security"
elif [ -f "${SOURCE_HOME}/.gitconfig" ] && [ -s "${SOURCE_HOME}/.gitconfig" ]; then
    cp -f "${SOURCE_HOME}/.gitconfig" "${TARGET_HOME}/.gitconfig"
    chmod 600 "${TARGET_HOME}/.gitconfig"
    echo "   ✅ .gitconfig"
elif [ -f "${SOURCE_HOME}/.gitconfig" ]; then
    echo "   ⚠️  .gitconfig exists but is empty"
else
    echo "   ℹ️  .gitconfig not found in staging"
fi

# ── Sync .npmrc ──────────────────────────────────────────────────────────────

if [ -L "${SOURCE_HOME}/.npmrc" ]; then
    echo "   ⚠️  .npmrc is a symlink, skipping for security"
elif [ -f "${SOURCE_HOME}/.npmrc" ] && [ -s "${SOURCE_HOME}/.npmrc" ]; then
    cp -f "${SOURCE_HOME}/.npmrc" "${TARGET_HOME}/.npmrc"
    chmod 600 "${TARGET_HOME}/.npmrc"
    echo "   ✅ .npmrc"
elif [ -f "${SOURCE_HOME}/.npmrc" ]; then
    echo "   ⚠️  .npmrc exists but is empty"
else
    echo "   ℹ️  .npmrc not found in staging"
fi

# ── Sync .ssh ────────────────────────────────────────────────────────────────

if [ -d "${SOURCE_HOME}/.ssh" ]; then
    mkdir -p "${TARGET_HOME}/.ssh"

    # Copy all regular files, skip symlinks for security
    find "${SOURCE_HOME}/.ssh" -maxdepth 1 -type f ! -type l -exec cp -f {} "${TARGET_HOME}/.ssh/" \;

    # Fix permissions
    chmod 700 "${TARGET_HOME}/.ssh"
    find "${TARGET_HOME}/.ssh" -name "id_*" ! -name "*.pub" -exec chmod 600 {} \;
    find "${TARGET_HOME}/.ssh" -name "*.pub" -exec chmod 644 {} \;
    [ -f "${TARGET_HOME}/.ssh/config" ] && chmod 600 "${TARGET_HOME}/.ssh/config"
    [ -f "${TARGET_HOME}/.ssh/known_hosts" ] && chmod 644 "${TARGET_HOME}/.ssh/known_hosts"

    # Report
    FILE_COUNT=$(find "${TARGET_HOME}/.ssh" -maxdepth 1 -type f | wc -l)
    echo "   ✅ .ssh (${FILE_COUNT} files)"
else
    echo "   ℹ️  .ssh not found in staging"
fi

# ── Sync .gnupg ──────────────────────────────────────────────────────────────

if [ -d "${SOURCE_HOME}/.gnupg" ]; then
    mkdir -p "${TARGET_HOME}/.gnupg"

    # Recursively mirror directories and regular files, skip sockets/symlinks
    (
        cd "${SOURCE_HOME}/.gnupg" || exit 1
        find . -type d -exec mkdir -p "${TARGET_HOME}/.gnupg/{}" \;
        find . -type f ! -type l -exec cp -f "{}" "${TARGET_HOME}/.gnupg/{}" \;
    )

    # Fix permissions recursively
    find "${TARGET_HOME}/.gnupg" -type d -exec chmod 700 {} \;
    find "${TARGET_HOME}/.gnupg" -type f -exec chmod 600 {} \;

    echo "   ✅ .gnupg"
else
    echo "   ℹ️  .gnupg not found in staging"
fi

# ── Fix ownership ────────────────────────────────────────────────────────────

if [ "$(id -u)" -eq 0 ] && getent passwd "${USERNAME}" >/dev/null 2>&1; then
    chown -R "${USERNAME}:${USERNAME}" \
        "${TARGET_HOME}/.ssh" \
        "${TARGET_HOME}/.gnupg" \
        "${TARGET_HOME}/.gitconfig" \
        "${TARGET_HOME}/.npmrc" 2>/dev/null || true
fi

# Signal sync completed (used by profile.d fallback)
touch /tmp/.local-mounts-synced 2>/dev/null || true

echo "✅ local-mounts: sync complete"
