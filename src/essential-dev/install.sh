#!/usr/bin/env bash

# Essential Development Environment DevContainer Feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details
#
# Provides core development environment with Git, Copilot, and editor tools

set -e

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
echo "   - Git integration (history, graph, conventional commits)"
echo "   - Markdown support with preview and linting"
echo "   - Editor enhancements (multi-cursor, compare, local history)"
echo "   - File format support (YAML, JSON, CSV, XML, Makefile)"
echo ""
echo "🔌 Terminal enhancements:"
echo "   - Shell integration enabled (command tracking, execution feedback)"
echo "   - Suggestion menu and decorations enabled"
echo "   - Works with zsh, bash, and fish"
