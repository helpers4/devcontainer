#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs nub (nubjs.com) — a single Rust binary that runs TypeScript/JS
# files, package.json scripts, and local CLIs on top of the Node.js and
# package manager already present, without installing a new runtime.
#
# Runs the official installer (https://nubjs.com/install.sh) as the target
# non-root user, not root, because the installer resolves its default
# install location from that user's $HOME — running it as root would put
# the binary in /root/.nub instead of the actual container user's home.
# NUB_NO_MODIFY_PATH=1 skips the installer's own ~/.bashrc / ~/.zshrc edits;
# system-wide availability is handled below via installGlobally instead,
# same pattern as vite-plus.

set -euo pipefail

# Bootstrap helpers4 shared library. helpers4-common installs it; if running
# standalone (e.g. devcontainer features test), create it inline so the feature
# is self-contained without a GHCR pull.
if [ ! -f /usr/local/share/helpers4/common.sh ]; then
    mkdir -p /usr/local/share/helpers4
    cat > /usr/local/share/helpers4/common.sh << 'H4_COMMON'
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
H4_COMMON
fi
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Feature options — env var names are the option id uppercased (devcontainers
# CLI convention for the modern manifest format; no _BUILD_ARG_ prefix here,
# that's only used for the legacy internalVersion:1 shape).
NUB_VERSION="${VERSION:-latest}"
INSTALL_GLOBALLY="${INSTALLGLOBALLY:-true}"

h4_detect_user
h4_resolve_home

echo "🔧 Installing nub feature..."
echo "  Username:         ${USERNAME}"
echo "  Home:              ${USER_HOME}"
echo "  Version:           ${NUB_VERSION}"
echo "  Install globally:  ${INSTALL_GLOBALLY}"

h4_ensure_packages ca-certificates curl tar

NUB_HOME="${USER_HOME}/.nub"
BIN_DIR="${NUB_HOME}/bin"

echo "📦 Downloading nub (${NUB_VERSION})..."
# Download to a temp file first — piping curl straight into bash makes a
# curl failure invisible to the pipeline's exit status (pipefail doesn't
# survive the su/bash -c boundary below anyway), same reason vite-plus does
# this. It also lets the version argument reach the installer as a real
# positional parameter instead of being interpolated into shell source,
# so a version string containing a quote can't inject commands.
INSTALLER_SCRIPT="$(mktemp)"
trap 'rm -f "${INSTALLER_SCRIPT}"' EXIT
if ! curl -fsSL https://nubjs.com/install.sh -o "${INSTALLER_SCRIPT}"; then
    echo "❌ Failed to download nub installer."
    exit 1
fi
chmod 644 "${INSTALLER_SCRIPT}"

if [ "${USERNAME}" = "root" ]; then
    NUB_INSTALL_DIR="${NUB_HOME}" NUB_NO_MODIFY_PATH=1 bash "${INSTALLER_SCRIPT}" "${NUB_VERSION}"
else
    # `su -c 'cmd' _ arg1 arg2` passes arg1/arg2 as $1/$2 inside cmd — env
    # vars prefixed on a single command (not a pipeline) propagate correctly,
    # and NUB_HOME/INSTALLER_SCRIPT/NUB_VERSION reach the child as real
    # positional params rather than text re-parsed by a shell.
    # shellcheck disable=SC2016 # single-quoted on purpose: $1/$2/$3 expand in the su'd shell, not here
    su -s /bin/bash "${USERNAME}" -c \
        'NUB_INSTALL_DIR="$1" NUB_NO_MODIFY_PATH=1 bash "$2" "$3"' \
        _ "${NUB_HOME}" "${INSTALLER_SCRIPT}" "${NUB_VERSION}"
fi

if [ ! -x "${BIN_DIR}/nub" ]; then
    echo "❌ nub installation failed — ${BIN_DIR}/nub not found or not executable."
    exit 1
fi
echo "  ✅ nub installed at ${BIN_DIR}/nub"

if [ "${INSTALL_GLOBALLY}" = "true" ]; then
    echo "🔗 Symlinking nub/nubx into /usr/local/bin..."
    for bin in "${BIN_DIR}"/*; do
        [ -e "${bin}" ] || continue
        name="$(basename "${bin}")"
        ln -sf "${bin}" "/usr/local/bin/${name}"
        echo "  ✅ /usr/local/bin/${name} -> ${bin}"
    done
else
    echo "ℹ️  installGlobally=false — nub is only on PATH for ${USERNAME} once they add ${BIN_DIR} to \$PATH themselves."
fi

echo ""
echo "🎉 nub feature installed successfully!"
echo ""
echo "📝 Usage:"
echo "   nub <file.ts>        # run a TS/JS file directly"
echo "   nub run <script>     # run a package.json script"
echo "   nubx <cli> [args]    # run a local CLI binary without the npx wrapper"
echo "   nub install          # install dependencies (detects npm/pnpm/bun lockfile)"
echo ""
echo "🔗 Resources:"
echo "   - nub: https://nubjs.com/"
echo "   - docs: https://nubjs.com/docs"
