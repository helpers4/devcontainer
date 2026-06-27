#!/usr/bin/env bash

# git-absorb DevContainer Feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details
#
# Installs git-absorb: automatically absorb staged changes into their logical commits

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

# Feature options
GIT_ABSORB_VERSION="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

h4_detect_user

# Clean up function
cleanup() {
    rm -rf /var/lib/apt/lists/*
    rm -f /tmp/git-absorb.tar.gz
}

trap cleanup EXIT

# Ensure apt is in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing git-absorb feature..."
echo "Username: $USERNAME"
echo "git-absorb version: $GIT_ABSORB_VERSION"

# Install dependencies
echo "🔧 Installing dependencies..."
h4_ensure_packages curl ca-certificates tar

# Ensure git is installed
if ! command -v git > /dev/null 2>&1; then
    h4_ensure_packages git
fi

# Detect architecture
architecture="$(uname -m)"
case $architecture in
    x86_64) architecture="x86_64-unknown-linux-musl";;
    aarch64 | armv8*) architecture="aarch64-unknown-linux-musl";;
    *) echo "(!) Architecture $architecture unsupported"; exit 1 ;;
esac

# Install git-absorb
echo "🎯 Installing git-absorb..."

if [ "${GIT_ABSORB_VERSION}" = "latest" ]; then
    echo "  📦 Fetching latest version..."
    GIT_ABSORB_VERSION=$(curl -s "https://api.github.com/repos/tummychow/git-absorb/releases/latest" | grep -o '"tag_name": "[^"]*"' | cut -d'"' -f4)
    if [ -z "${GIT_ABSORB_VERSION}" ]; then
        echo "(!) Failed to fetch latest version"
        exit 1
    fi
fi

# Extract version number for file names (remove 'v' prefix if present)
if [ "${GIT_ABSORB_VERSION::1}" = 'v' ]; then
    VERSION_NUMBER="${GIT_ABSORB_VERSION:1}"
else
    VERSION_NUMBER="${GIT_ABSORB_VERSION}"
fi

echo "  📦 Downloading git-absorb ${GIT_ABSORB_VERSION}..."

# Download from GitHub releases (use original tag name for URL path)
DOWNLOAD_URL="https://github.com/tummychow/git-absorb/releases/download/${GIT_ABSORB_VERSION}/git-absorb-${VERSION_NUMBER}-${architecture}.tar.gz"

if ! curl -fL "${DOWNLOAD_URL}" -o /tmp/git-absorb.tar.gz; then
    echo "(!) Failed to download git-absorb from ${DOWNLOAD_URL}"
    echo "(!) Available releases: https://github.com/tummychow/git-absorb/releases"
    exit 1
fi

# Extract and install
echo "  📦 Installing git-absorb..."
cd /tmp
tar -xzf git-absorb.tar.gz

# Find the binary (might be in a subdirectory)
BINARY_PATH=$(find /tmp -name "git-absorb" -type f -executable 2>/dev/null | head -1)

if [ -z "${BINARY_PATH}" ]; then
    echo "(!) Could not find git-absorb binary in downloaded archive"
    ls -la /tmp/
    exit 1
fi

# Install to /usr/local/bin
cp "${BINARY_PATH}" /usr/local/bin/git-absorb
chmod +x /usr/local/bin/git-absorb

# Verify installation
if ! /usr/local/bin/git-absorb --version > /dev/null 2>&1; then
    echo "(!) git-absorb installation verification failed"
    exit 1
fi

# Get installed version for confirmation
INSTALLED_VERSION="$(/usr/local/bin/git-absorb --version 2>&1 | grep -o '[0-9.]*' | head -1 || echo 'unknown')"
echo "  ✅ git-absorb ${INSTALLED_VERSION} installed successfully"

echo
echo "🎉 git-absorb installation complete!"
echo

# git absorb alias: whole-file matching, scoped to local (unpushed) commits
git config --system alias.absorb 'absorb --whole-file --base origin/HEAD'
echo "  ✅ git absorb -> git absorb --whole-file --base origin/HEAD"

echo "📋 Usage:"
echo "  git add <files>          # Stage your changes"
echo "  git absorb               # Absorb staged changes into local commits (whole-file, up to origin/HEAD)"
echo "  git absorb --dry-run     # Preview what would be absorbed"
echo
echo "🚀 Ready to use:"
echo "  git absorb --help"
echo
