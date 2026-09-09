#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Sets up Vite+ development environment with the unified vp CLI,
# Oxc formatter/linter, Vitest, and VS Code configuration

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

echo "🔧 Setting up vite-plus devcontainer feature..."

# Get options
INSTALL_VITE_PLUS="${INSTALLVITEPLUS:-true}"
INSTALL_GLOBALLY="${INSTALLGLOBALLY:-true}"
INSTALL_VITE="${INSTALLVITE:-false}"
INSTALL_VITEST="${INSTALLVITEST:-false}"
INSTALL_OXC="${INSTALLOXC:-false}"

# Detect non-root user
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root."
    exit 1
fi

h4_detect_user
h4_resolve_home

# Ensure apt is in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

# Check if node/npm is available (needed for fallback tools and npm-based installs)
if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm not found. Please ensure Node.js feature is installed first."
    exit 1
fi

# Install Vite+ unified CLI (vp) via the official installer
if [ "$INSTALL_VITE_PLUS" = "true" ]; then
    echo "📦 Installing Vite+ unified CLI (vp) via official installer..."

    # Ensure curl and ca-certificates are available
    h4_ensure_packages curl ca-certificates

    # Download installer to a temp file to avoid pipefail issues
    INSTALLER_SCRIPT=$(mktemp)
    trap 'rm -f "$INSTALLER_SCRIPT"' EXIT

    if ! curl -fsSL https://vite.plus -o "$INSTALLER_SCRIPT"; then
        echo "❌ Failed to download Vite+ installer."
        exit 1
    fi
    chmod 644 "$INSTALLER_SCRIPT"

    # Install vp for the devcontainer user (per-user install in ~/.vite-plus/bin).
    # VP_HOME pins the installer to that monolithic layout — without it, the
    # installer defaults to an XDG split layout (~/.local/share/vite-plus/bin)
    # unless an existing ~/.vite-plus is already there, which silently broke
    # every path check below. VP_NODE_MANAGER=no skips the installer's
    # interactive Node-manager prompt, per its own documented CI/devcontainer
    # support.
    if [ "$USERNAME" != "root" ]; then
        USER_VP_HOME="${USER_HOME}/.vite-plus"
        if su - "$USERNAME" -c "VP_HOME='${USER_VP_HOME}' VP_NODE_MANAGER=no bash '$INSTALLER_SCRIPT'"; then
            if [ ! -x "${USER_VP_HOME}/bin/vp" ]; then
                echo "❌ Vite+ installer exited successfully, but ${USER_VP_HOME}/bin/vp is missing."
                exit 1
            fi
            echo "✅ Vite+ CLI (vp) installed at ${USER_VP_HOME}/bin"

            # Verify vp is available for the user
            if su - "$USERNAME" -c 'command -v vp' >/dev/null 2>&1; then
                VP_VERSION=$(su - "$USERNAME" -c 'vp --version 2>/dev/null' || echo "unknown")
                echo "   Version: ${VP_VERSION}"
            else
                echo "   vp installed, will be available in new shell sessions for ${USERNAME}"
            fi

            # Optionally symlink into /usr/local/bin so vp is available system-wide
            # (root, sudo, other users, scripts that don't source the user's profile).
            # vp resolves its own location at runtime, so a symlink is enough — no
            # need to copy the install or duplicate node_modules.
            if [ "$INSTALL_GLOBALLY" = "true" ]; then
                if ln -sfn "${USER_VP_HOME}/bin/vp" /usr/local/bin/vp; then
                    echo "✅ vp symlinked to /usr/local/bin/vp (available system-wide)"
                else
                    echo "⚠️  Failed to create /usr/local/bin/vp symlink"
                fi
            fi
        else
            echo "❌ Failed to install Vite+ CLI via official installer."
            exit 1
        fi
    else
        # Root-only fallback
        VP_HOME="${HOME}/.vite-plus"
        export VP_HOME
        export VP_NODE_MANAGER=no
        if bash "$INSTALLER_SCRIPT"; then
            if [ ! -x "${VP_HOME}/bin/vp" ]; then
                echo "❌ Vite+ installer exited successfully, but ${VP_HOME}/bin/vp is missing."
                exit 1
            fi
            echo "✅ Vite+ CLI (vp) installed"
            export PATH="${VP_HOME}/bin:${PATH}"
            VP_VERSION=$(vp --version 2>/dev/null || echo "unknown")
            echo "   Version: ${VP_VERSION}"

            # Symlink for system-wide availability when running as root only
            if [ "$INSTALL_GLOBALLY" = "true" ]; then
                if ln -sfn "${VP_HOME}/bin/vp" /usr/local/bin/vp; then
                    echo "✅ vp symlinked to /usr/local/bin/vp (available system-wide)"
                else
                    echo "⚠️  Failed to create /usr/local/bin/vp symlink"
                fi
            fi
        else
            echo "❌ Failed to install Vite+ CLI via official installer."
            exit 1
        fi
    fi
fi

# Install standalone Oxc language server if requested (not needed with vp)
if [ "$INSTALL_OXC" = "true" ]; then
    echo "📦 Installing Oxc language server globally..."
    if npm install -g oxc-language-server 2>/dev/null; then
        echo "✅ Oxc language server installed"
    else
        echo "⚠️  Failed to install Oxc language server, but continuing..."
    fi
fi

# Install standalone Vite CLI if requested (not needed with vp)
if [ "$INSTALL_VITE" = "true" ]; then
    echo "📦 Installing Vite CLI globally..."
    if npm install -g vite 2>/dev/null; then
        echo "✅ Vite CLI installed"
        if command -v vite >/dev/null 2>&1; then
            VITE_VERSION=$(vite --version 2>/dev/null || echo "unknown")
            echo "   Version: ${VITE_VERSION}"
        fi
    else
        echo "⚠️  Failed to install Vite CLI, but continuing..."
    fi
fi

# Install standalone Vitest CLI if requested (not needed with vp)
if [ "$INSTALL_VITEST" = "true" ]; then
    echo "📦 Installing Vitest CLI globally..."
    if npm install -g vitest 2>/dev/null; then
        echo "✅ Vitest CLI installed"
        if command -v vitest >/dev/null 2>&1; then
            VITEST_VERSION=$(vitest --version 2>/dev/null || echo "unknown")
            echo "   Version: ${VITEST_VERSION}"
        fi
    else
        echo "⚠️  Failed to install Vitest CLI, but continuing..."
    fi
fi

echo ""
echo "✅ Vite+ feature installed successfully!"
echo ""
echo "📝 Vite+ unified commands:"
echo "   vp create    - Scaffold a new project"
echo "   vp install   - Install dependencies"
echo "   vp dev       - Start dev server"
echo "   vp check     - Lint (Oxlint) + format (Oxfmt) + type-check (tsgo)"
echo "   vp test      - Run tests (Vitest)"
echo "   vp build     - Production build (Rolldown)"
echo "   vp run       - Execute package.json scripts via Vite Task"
echo "   vp pack      - Bundle libraries or create standalone binaries"
echo ""
echo "🔗 Resources:"
echo "   - Vite+: https://viteplus.dev/"
echo "   - Vitest: https://vitest.dev/"
echo "   - Oxc: https://oxc.rs/"
echo "   - Vite: https://vite.dev/"
