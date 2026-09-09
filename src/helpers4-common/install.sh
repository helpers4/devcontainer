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
# Docker creates a named volume root-owned. Without --shared (a volume exclusive to one
# container, e.g. keyed by ${devcontainerId}), always chown to the current user — nothing
# else can be concurrently using that exact volume. With --shared (deliberately shared
# across every concurrently-running container for the same host user, e.g. keyed by
# ${localEnv:USER}), claim ownership only the first time, while it's still root-owned; if
# it already belongs to a *different* non-root user (another project's container,
# possibly still running), don't steal it out from under that session — grant world
# read/write instead, so every UID can use it without an ownership tug-of-war on every
# start. Best-effort either way: warns, never fails, if chown/chmod can't succeed.
h4_ensure_volume_writable() {
    local _path="$1" _shared="false" _owner
    [ "${2:-}" = "--shared" ] && _shared="true"
    _owner="$(stat -c '%u' "${_path}" 2>/dev/null || echo 'unknown')"
    if [ "${_shared}" = "true" ] && [ "${_owner}" != "0" ] && [ "${_owner}" != "$(id -u)" ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo chmod -R o+rwX "${_path}" \
                || echo "⚠️  h4_ensure_volume_writable: chmod of ${_path} failed — writes may fail (EACCES)" >&2
        else
            echo "⚠️  h4_ensure_volume_writable: ${_path} is owned by uid ${_owner} and sudo is unavailable — writes will fail (EACCES)" >&2
        fi
    elif [ "${_owner}" != "$(id -u)" ]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo chown -R "$(id -u):$(id -g)" "${_path}" \
                || echo "⚠️  h4_ensure_volume_writable: chown of ${_path} failed — writes may fail (EACCES)" >&2
        else
            echo "⚠️  h4_ensure_volume_writable: ${_path} needs chown and sudo is unavailable — writes will fail (EACCES)" >&2
        fi
    fi
}
h4_arch_musl_triple() {
    local arch
    arch="$(uname -m)"
    case "${arch}" in
        x86_64) echo "x86_64-unknown-linux-musl" ;;
        aarch64 | arm64 | armv8*) echo "aarch64-unknown-linux-musl" ;;
        *) echo "(!) Architecture ${arch} unsupported" >&2; return 1 ;;
    esac
}
h4_github_latest_tag() {
    local repo="$1" prefix="${2:-}"
    # grep -o exits 1 on no match, which under the caller's `set -o pipefail`
    # would otherwise abort the script right here on any transient API
    # hiccup, with no diagnostic — the trailing `|| true` lets the caller's
    # own empty-result check handle that instead.
    if [ -n "${prefix}" ]; then
        curl -s "https://api.github.com/repos/${repo}/releases" \
            | grep -o "\"tag_name\": *\"${prefix}[^\"]*\"" | head -1 | cut -d'"' -f4 || true
    else
        curl -s "https://api.github.com/repos/${repo}/releases/latest" \
            | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 || true
    fi
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
