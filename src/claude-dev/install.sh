#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# claude-dev: installs the Claude Code IDE extension.
# The actual extension installation is handled by the devcontainer runtime via
# the "customizations" field in devcontainer-feature.json. This script only
# prints a summary so the feature shows up in the build log.

set -euo pipefail

echo "🤖 Setting up claude-dev devcontainer feature..."
echo ""
echo "IDE extensions (installed by the devcontainer runtime):"
echo "   VS Code / Cursor : anthropic.claude-code"
echo ""
echo "✅ claude-dev feature configured!"
