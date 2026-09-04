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
    if ! command -v npm >/dev/null 2>&1; then
        echo "  ⚠️  npm not found — skipping Cline CLI install." >&2
        echo "      Add a Node.js feature (e.g. ghcr.io/devcontainers/features/node) before cline-dev, or install manually: npm install -g cline" >&2
    else
        # The cline package requires Node 22+; npm only warns (doesn't fail)
        # on an engine mismatch, so check explicitly rather than end up with
        # a CLI on PATH that fails at runtime with no build-time signal.
        NODE_MAJOR=0
        if command -v node >/dev/null 2>&1; then
            NODE_MAJOR="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
        fi
        if [ "${NODE_MAJOR}" -lt 22 ] 2>/dev/null; then
            echo "  ⚠️  Node.js $(node --version 2>/dev/null || echo 'not found') — Cline CLI requires Node 22+, skipping install." >&2
        # A transient network/registry failure here must not abort the whole
        # feature build — degrade gracefully like the "npm not found" branch.
        elif npm install -g cline; then
            echo "  ✅ cline CLI installed: $(cline --version 2>/dev/null || echo 'ok')"
        else
            echo "  ⚠️  npm install -g cline failed — skipping (network issue or registry unreachable?)." >&2
        fi
    fi
fi

echo ""
echo "🎉 cline-dev configuration complete!"
