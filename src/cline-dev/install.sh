#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME.
# Optionally installs the Cline CLI.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

INSTALL_CLI="${_BUILD_ARG_INSTALLCLI:-${INSTALLCLI:-false}}"

echo "🔧 Configuring cline-dev feature..."
echo "  Install CLI: ${INSTALL_CLI}"

if [ "${INSTALL_CLI}" = "true" ]; then
    if command -v npm >/dev/null 2>&1; then
        npm install -g cline
        echo "  ✅ cline CLI installed: $(cline --version 2>/dev/null || echo 'ok')"
    else
        echo "  ⚠️  npm not found — skipping Cline CLI install." >&2
        echo "      Add a Node.js feature (e.g. ghcr.io/devcontainers/features/node) before cline-dev, or install manually: npm install -g cline" >&2
    fi
else
    echo "  Skipping Cline CLI install (installCli=false)."
fi

echo ""
echo "🎉 cline-dev configuration complete!"
