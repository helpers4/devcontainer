#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs github-dev devcontainer feature.
# - GitHub CLI (gh) from GitHub Releases (skipped if already installed)

set -e

GH_VERSION="${_BUILD_ARG_GHVERSION:-"${GHVERSION:-"latest"}"}"

echo "Setting up github-dev devcontainer feature..."
echo "   gh version requested: ${GH_VERSION}"
echo ""

# ============================================================================
# 1. Check if gh is already installed
# ============================================================================

if command -v gh >/dev/null 2>&1; then
    EXISTING_VER="$(gh --version | head -1)"
    if [ "${GH_VERSION}" = "latest" ]; then
        echo "gh already installed (${EXISTING_VER}), skipping installation"
        GH_INSTALLED=true
    else
        EXISTING_VER_NUM="$(gh --version | head -1 | awk '{print $3}')"
        if [ "${EXISTING_VER_NUM}" = "${GH_VERSION}" ]; then
            echo "gh ${GH_VERSION} already installed, skipping installation"
            GH_INSTALLED=true
        else
            echo "gh ${EXISTING_VER_NUM} installed but ${GH_VERSION} requested, upgrading..."
            GH_INSTALLED=false
        fi
    fi
else
    GH_INSTALLED=false
fi

# ============================================================================
# 2. Install GitHub CLI (gh) if needed
# ============================================================================

if [ "${GH_INSTALLED}" = "false" ]; then
    ARCH="$(uname -m)"
    case "${ARCH}" in
        x86_64)  GH_ARCH="amd64" ;;
        aarch64) GH_ARCH="arm64" ;;
        armv7l)  GH_ARCH="armv6" ;;
        *)
            echo "Unsupported architecture: ${ARCH}"
            exit 1
            ;;
    esac

    echo "Architecture: ${ARCH} -> ${GH_ARCH}"

    # Resolve 'latest' to an actual version number
    if [ "${GH_VERSION}" = "latest" ]; then
        echo "Resolving latest gh version..."
        GH_VERSION="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
            | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')"
        if [ -z "${GH_VERSION}" ]; then
            echo "Failed to resolve latest gh version, aborting"
            exit 1
        fi
        echo "Latest gh version: ${GH_VERSION}"
    fi

    GH_TARBALL="gh_${GH_VERSION}_linux_${GH_ARCH}.tar.gz"
    GH_URL="https://github.com/cli/cli/releases/download/v${GH_VERSION}/${GH_TARBALL}"
    GH_TMP="$(mktemp -d)"

    cleanup() { rm -rf "${GH_TMP}"; }
    trap cleanup EXIT

    echo "Downloading gh ${GH_VERSION} (${GH_ARCH})..."
    curl -fsSL "${GH_URL}" -o "${GH_TMP}/${GH_TARBALL}"

    echo "Installing gh..."
    tar -xzf "${GH_TMP}/${GH_TARBALL}" -C "${GH_TMP}"
    install -m 0755 "${GH_TMP}/gh_${GH_VERSION}_linux_${GH_ARCH}/bin/gh" /usr/local/bin/gh
fi

# Verify
if gh --version >/dev/null 2>&1; then
    echo "gh ready: $(gh --version | head -1)"
else
    echo "gh verification failed"
    exit 1
fi

# ============================================================================
# 3. Install gh auto-auth profile.d script
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 0644 "${SCRIPT_DIR}/gh-auth.sh" /etc/profile.d/gh-auth.sh
echo "gh-auth.sh installed to /etc/profile.d/gh-auth.sh"

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "github-dev feature installed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Installed:"
echo "   $(gh --version | head -1)"
echo ""
echo "Auto-auth: set GH_TOKEN or GITHUB_TOKEN env var to authenticate gh on shell startup"
echo ""
echo "VS Code extensions (installed by devcontainer spec):"
echo "   github.copilot"
echo "   github.copilot-chat"
echo "   github.vscode-pull-request-github"
echo "   github.vscode-github-actions"
echo "   github.remotehub"
