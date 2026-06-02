#!/usr/bin/env bash

# Angular Development Environment DevContainer Feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details
#
# Configures Angular development environment with CLI autocompletion

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
INSTALL_CLI="${INSTALLCLI:-false}"

echo "🔧 Installing angular-dev devcontainer feature..."

# Install Angular CLI if requested
if [ "$INSTALL_CLI" = "true" ]; then
    echo "📦 Installing Angular CLI globally..."
    if command -v npm >/dev/null 2>&1; then
        npm install -g @angular/cli
        echo "✅ Angular CLI installed"
    elif command -v pnpm >/dev/null 2>&1; then
        pnpm add -g @angular/cli
        echo "✅ Angular CLI installed via pnpm"
    else
        echo "❌ ERROR: npm or pnpm not found. Cannot install Angular CLI."
        echo "   Please ensure Node.js is installed first."
        exit 1
    fi
fi

h4_detect_user
h4_resolve_home

# Setup Angular CLI autocompletion for zsh
setup_zsh_completion() {
    local zshrc="${USER_HOME}/.zshrc"

    if [ -f "$zshrc" ] || command -v zsh >/dev/null 2>&1; then
        # Create .zshrc if it doesn't exist
        touch "$zshrc"

        # Check if autocompletion is already configured
        if ! grep -q "ng completion" "$zshrc" 2>/dev/null; then
            echo "" >> "$zshrc"
            echo "# Angular CLI autocompletion" >> "$zshrc"
            echo "if command -v ng >/dev/null 2>&1; then" >> "$zshrc"
            echo "  source <(ng completion script) 2>/dev/null" >> "$zshrc"
            echo "fi" >> "$zshrc"
            echo "✅ Angular CLI autocompletion added to .zshrc"
        else
            echo "ℹ️  Angular CLI autocompletion already configured in .zshrc"
        fi
    fi
}

# Setup Angular CLI autocompletion for bash
setup_bash_completion() {
    local bashrc="${USER_HOME}/.bashrc"

    if [ -f "$bashrc" ] || command -v bash >/dev/null 2>&1; then
        # Create .bashrc if it doesn't exist
        touch "$bashrc"

        # Check if autocompletion is already configured
        if ! grep -q "ng completion" "$bashrc" 2>/dev/null; then
            echo "" >> "$bashrc"
            echo "# Angular CLI autocompletion" >> "$bashrc"
            echo "if command -v ng >/dev/null 2>&1; then" >> "$bashrc"
            echo "  source <(ng completion script) 2>/dev/null" >> "$bashrc"
            echo "fi" >> "$bashrc"
            echo "✅ Angular CLI autocompletion added to .bashrc"
        else
            echo "ℹ️  Angular CLI autocompletion already configured in .bashrc"
        fi
    fi
}

# Setup autocompletion
echo "📝 Configuring Angular CLI autocompletion..."
setup_zsh_completion
setup_bash_completion

# Verify Angular CLI if available
if command -v ng >/dev/null 2>&1; then
    NG_VERSION=$(ng version 2>/dev/null | grep "Angular CLI" | awk '{print $3}' || echo "unknown")
    echo "✅ Angular CLI found: ${NG_VERSION}"
else
    echo "ℹ️  Angular CLI not found yet"
    echo "   It will be available after installing it or using another feature"
    echo "   Autocompletion will activate automatically when ng is available"
fi

echo ""
echo "🎉 Angular development environment configured!"
echo ""
echo "📋 Configuration summary:"
echo "   - Port 4200 forwarded for Angular dev server"
echo "   - VS Code extensions for Angular development installed"
echo "   - CLI autocompletion configured for zsh and bash"
echo ""
echo "🚀 Quick start:"
echo "   ng new my-app    # Create a new Angular app"
echo "   ng serve         # Start the dev server (port 4200)"
echo "   ng generate      # Generate components, services, etc."
