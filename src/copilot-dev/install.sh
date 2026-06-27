#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME.
# Installs the gh-copilot CLI extension.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

INSTALL_CLI="${_BUILD_ARG_INSTALLCLI:-${INSTALLCLI:-true}}"

echo "🔧 Configuring copilot-dev feature..."
echo "  Install CLI: ${INSTALL_CLI}"

# ── Install gh copilot CLI extension ─────────────────────────────────────────
if [ "${INSTALL_CLI}" = "true" ]; then
    if ! command -v gh >/dev/null 2>&1; then
        echo "  ⚠️  gh CLI not found — skipping gh copilot extension install."
        echo "      Add github-dev before copilot-dev, or install gh manually."
    else
        echo "  Installing gh copilot extension..."
        gh extension install github/gh-copilot --force
        echo "  ✅ gh copilot extension installed: $(gh copilot --version 2>/dev/null || echo 'ok')"
    fi
else
    echo "  Skipping gh copilot CLI install (installCli=false)."
fi

echo ""
echo "🎉 copilot-dev configuration complete!"
