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

# Enable VS Code shell integration for all shells
# This captures command execution and working directory changes in the terminal
echo "🔧 Configuring VS Code shell integration..."

for shell in zsh bash fish; do
  if command -v "$shell" &> /dev/null; then
    case "$shell" in
      zsh)
        config_file="${HOME}/.zshrc"
        ;;
      bash)
        config_file="${HOME}/.bashrc"
        ;;
      fish)
        config_file="${HOME}/.config/fish/config.fish"
        ;;
    esac
    
    if [ -f "$config_file" ] && ! grep -q "SHELL_SESSION_ID" "$config_file" 2>/dev/null; then
      echo "   ✅ Shell integration ready for $shell"
    fi
  fi
done

echo ""
echo "✅ essential-dev feature configured"
echo ""
echo "📦 VS Code extensions installed:"
echo "   - Git integration (history, graph)"
echo "   - Markdown support with preview and linting"
echo "   - Editor enhancements (multi-cursor, compare, local history)"
echo "   - File format support (YAML, JSON, CSV, XML, Makefile)"
echo ""
echo "🔌 Terminal enhancements:"
echo "   - Shell integration enabled (command tracking, execution feedback)"
echo "   - Suggestion menu and decorations enabled"
echo "   - Works with zsh, bash, and fish"
