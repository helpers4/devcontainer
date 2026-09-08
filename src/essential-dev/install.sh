#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Provides core development environment with Git, Markdown, and editor tools.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

# Ensure git is available (ubuntu:latest is a minimal image with no git)
h4_ensure_packages git

# Git workflow aliases
git config --system alias.fixup 'commit --fixup'
git config --system alias.polish 'rebase -i --autosquash origin/HEAD'

echo "✅ essential-dev feature configured"
echo ""
echo "📦 VS Code extensions installed:"
echo "   - Git integration (history, graph)"
echo "   - Markdown support with preview and linting"
echo "   - Editor enhancements (multi-cursor, compare, local history)"
echo "   - File format support (YAML, JSON, CSV, XML, Makefile)"
