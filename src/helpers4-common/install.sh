#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# helpers4-common: install the shared helpers4 library.
# All other helpers4 features depend on this feature.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root."
    exit 1
fi

echo "🔧 Installing helpers4-common..."

# ── Install common.sh ──────────────────────────────────────────────────────
COMMON_DIR="/usr/local/share/helpers4"
COMMON_SH="${COMMON_DIR}/common.sh"
mkdir -p "${COMMON_DIR}"

# Delimiter H4_COMMON matches every feature's inline bootstrap so the CI sync
# check can extract and diff the canonical against all copies with one pattern.
cat > "${COMMON_SH}" << 'H4_COMMON'
# shellcheck shell=bash
h4_detect_user() {
    USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        USERNAME=""
        local _uid1000
        _uid1000="$(awk -v val=1000 -F: '$3==val{print $1; exit}' /etc/passwd 2>/dev/null || true)"
        local candidate
        for candidate in vscode node codespace "${_uid1000}"; do
            if [ -n "${candidate}" ] && id -u "${candidate}" >/dev/null 2>&1; then
                USERNAME="${candidate}"; break
            fi
        done
        [ -z "${USERNAME}" ] && USERNAME=root
    elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
        USERNAME=root
    fi
    export USERNAME
}
h4_resolve_home() {
    if [ "${USERNAME}" = "root" ]; then
        USER_HOME=/root
    else
        USER_HOME="$(getent passwd "${USERNAME}" 2>/dev/null | cut -d: -f6)"
        [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
    fi
    export USER_HOME
}
h4_apt_update() {
    if [ "$(find /var/lib/apt/lists -maxdepth 1 \( -name '*.lz4' -o -name '*.gz' \) 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y -q
    fi
}
h4_ensure_packages() {
    local missing=() pkg
    for pkg in "$@"; do dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        h4_apt_update
        apt-get install -y -q --no-install-recommends "${missing[@]}"
    fi
}
h4_detect_cloud_env() {
    IS_CLOUD_ENV=false
    ENV_LABEL="local"
    if [ "${CODESPACES:-}" = "true" ] || [ -n "${CODESPACE_NAME:-}" ]; then
        IS_CLOUD_ENV=true
        ENV_LABEL="GitHub Codespaces"
    elif [ -n "${GITPOD_WORKSPACE_ID:-}" ] || [ -n "${GITPOD_INSTANCE_ID:-}" ]; then
        IS_CLOUD_ENV=true
        ENV_LABEL="Gitpod"
    elif [ "${DEVPOD:-}" = "true" ] || [ -n "${DEVPOD_WORKSPACE_ID:-}" ]; then
        IS_CLOUD_ENV=true
        ENV_LABEL="DevPod"
    elif grep -qi "microsoft\|wsl" /proc/version 2>/dev/null; then
        ENV_LABEL="WSL"
    fi
    export IS_CLOUD_ENV ENV_LABEL
}
H4_COMMON

chmod 644 "${COMMON_SH}"
echo "  ✅ Installed ${COMMON_SH}"

# ── Install the git-config self-heal script ──────────────────────────────────
# Fully generic at runtime (reads whatever's in $HOME/.gitconfig when it
# actually runs) — nothing to bake in at build time, so a plain file drop is
# enough; see the script's own header for what it does and why.
SELF_HEAL_SH="${COMMON_DIR}/git-config-self-heal.sh"
cp "$(dirname "$0")/git-config-self-heal.sh" "${SELF_HEAL_SH}"
chmod 755 "${SELF_HEAL_SH}"
echo "  ✅ Installed ${SELF_HEAL_SH}"

echo "🎉 helpers4-common ready."
