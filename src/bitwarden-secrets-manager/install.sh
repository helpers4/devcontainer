#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs bws, the official Bitwarden Secrets Manager CLI

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
BWS_VERSION_INPUT="${VERSION:-"latest"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

h4_detect_user

cleanup() {
    rm -rf /tmp/bws-*
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing bitwarden-secrets-manager feature..."
echo "Username: ${USERNAME}"
echo "bws version: ${BWS_VERSION_INPUT}"

echo "🔧 Installing dependencies..."
h4_ensure_packages curl ca-certificates unzip

# bitwarden/sdk-sm is a monorepo releasing multiple SDKs under one releases
# list (python-vX.Y.Z, napi-vX.Y.Z, bws-vX.Y.Z, ...) — /releases/latest can
# return any of them, not necessarily a bws release, so "latest" must filter
# by tag prefix rather than trust that endpoint.
case "${BWS_VERSION_INPUT}" in
    latest)
        echo "  📦 Fetching latest bws release..."
        # grep -o exits 1 on no match, which under pipefail would otherwise
        # kill the script right here — before the check below ever runs — on
        # any transient API hiccup, with no diagnostic. The trailing
        # `|| true` lets that check do its job instead.
        BWS_TAG="$(curl -s "https://api.github.com/repos/bitwarden/sdk-sm/releases" | grep -o '"tag_name": *"bws-[^"]*"' | head -1 | cut -d'"' -f4 || true)"
        if [ -z "${BWS_TAG}" ]; then
            echo "(!) Failed to fetch latest bws release"
            exit 1
        fi
        ;;
    bws-v*)
        BWS_TAG="${BWS_VERSION_INPUT}"
        ;;
    *)
        BWS_TAG="bws-v${BWS_VERSION_INPUT}"
        ;;
esac

VERSION_NUMBER="${BWS_TAG#bws-v}"

# This script only ever runs inside the (always-Linux) devcontainer being
# built, never on the host — so unlike bws's own multi-OS releases, there is
# no Darwin case to detect here. Only the architecture varies (Oracle Cloud
# Ampere A1 targets are aarch64).
architecture="$(uname -m)"
case "${architecture}" in
    x86_64) target="x86_64-unknown-linux-musl" ;;
    aarch64 | arm64) target="aarch64-unknown-linux-musl" ;;
    *) echo "(!) Architecture ${architecture} unsupported"; exit 1 ;;
esac

ASSET_NAME="bws-${target}-${VERSION_NUMBER}.zip"
CHECKSUMS_NAME="bws-sha256-checksums-${VERSION_NUMBER}.txt"
RELEASE_URL="https://github.com/bitwarden/sdk-sm/releases/download/${BWS_TAG}"

echo "  📦 Downloading ${ASSET_NAME} (${BWS_TAG})..."
if ! curl -fL "${RELEASE_URL}/${ASSET_NAME}" -o "/tmp/${ASSET_NAME}"; then
    echo "(!) Failed to download bws from ${RELEASE_URL}/${ASSET_NAME}"
    echo "(!) Available releases: https://github.com/bitwarden/sdk-sm/releases"
    exit 1
fi

echo "  🔒 Verifying checksum..."
if ! curl -fsL "${RELEASE_URL}/${CHECKSUMS_NAME}" -o "/tmp/${CHECKSUMS_NAME}"; then
    echo "(!) Failed to download checksums file from ${RELEASE_URL}/${CHECKSUMS_NAME}"
    exit 1
fi
if ! (cd /tmp && grep " ${ASSET_NAME}\$" "${CHECKSUMS_NAME}" | sha256sum -c -); then
    echo "(!) Checksum verification failed for ${ASSET_NAME}"
    exit 1
fi

echo "  📦 Installing bws..."
unzip -oq "/tmp/${ASSET_NAME}" -d /tmp/bws-extracted
install -m 0755 /tmp/bws-extracted/bws /usr/local/bin/bws

if ! /usr/local/bin/bws --version > /dev/null 2>&1; then
    echo "(!) bws installation verification failed"
    exit 1
fi

INSTALLED_VERSION="$(/usr/local/bin/bws --version 2>&1 | tr -d '\r')"
echo "  ✅ ${INSTALLED_VERSION} installed successfully"

echo
echo "🎉 bitwarden-secrets-manager installation complete!"
echo
echo "📋 Usage:"
echo "  export BWS_ACCESS_TOKEN=<your machine account access token>"
echo "  bws secret list"
echo "  bws secret get <secret-id>"
echo
