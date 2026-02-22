#!/bin/bash

# Shell History Per Project DevContainer Feature
# Copyright (c) 2025 helpers4
# Licensed under AGPL-3.0 - see LICENSE file for details

set -e

# Get options
HISTORY_DIRECTORY=${HISTORYDIRECTORY:-"/workspaces/.shell-history"}
MAX_HISTORY_SIZE=${MAXHISTORYSIZE:-"10000"}
SHELL_OPTION=${SHELL:-"auto"}

# Auto-detect user (without common-utils dependency)
_REMOTE_USER="${_REMOTE_USER:-"${USERNAME:-"${USER:-"$(whoami 2>/dev/null || echo root)"}"}"}"
_REMOTE_USER_HOME="${_REMOTE_USER_HOME:-""}"

if [ -z "$_REMOTE_USER_HOME" ]; then
    if [ "$_REMOTE_USER" = "root" ]; then
        _REMOTE_USER_HOME="/root"
    else
        _REMOTE_USER_HOME="/home/$_REMOTE_USER"
    fi
fi

# Auto-detect available shells
AVAILABLE_SHELLS=""
if command -v zsh >/dev/null 2>&1; then
    AVAILABLE_SHELLS="$AVAILABLE_SHELLS zsh"
fi
if command -v bash >/dev/null 2>&1; then
    AVAILABLE_SHELLS="$AVAILABLE_SHELLS bash"
fi
if command -v fish >/dev/null 2>&1; then
    AVAILABLE_SHELLS="$AVAILABLE_SHELLS fish"
fi

# Determine which shells to configure
if [ "$SHELL_OPTION" = "auto" ]; then
    SHELLS_TO_CONFIGURE="$AVAILABLE_SHELLS"
    echo "Auto-detecting shells: configuring all available shells"
else
    # Check if specified shell is available
    if echo "$AVAILABLE_SHELLS" | grep -q "$SHELL_OPTION"; then
        SHELLS_TO_CONFIGURE="$SHELL_OPTION"
        echo "Using specified shell: $SHELL_OPTION"
    else
        echo "Warning: Specified shell '$SHELL_OPTION' not found. Available shells: $AVAILABLE_SHELLS"
        if [ -n "$AVAILABLE_SHELLS" ]; then
            SHELLS_TO_CONFIGURE="$AVAILABLE_SHELLS"
            echo "Falling back to auto-detection"
        else
            echo "No supported shells found. Exiting."
            exit 1
        fi
    fi
fi

echo "Installing shell-history-per-project feature..."
echo "User: $_REMOTE_USER"
echo "User home: $_REMOTE_USER_HOME"
echo "Available shells:$AVAILABLE_SHELLS"
echo "Shells to configure:$SHELLS_TO_CONFIGURE"
echo "History directory: $HISTORY_DIRECTORY"
echo "Max history size: $MAX_HISTORY_SIZE"

# Create the history directory
mkdir -p "$HISTORY_DIRECTORY"

# Function to setup shell history for different shells
setup_shell_history() {
    local shell_name="$1"
    local history_file=""
    local config_file=""
    local history_var=""
    
    case "$shell_name" in
        "zsh")
            history_file="$HISTORY_DIRECTORY/.zsh_history"
            config_file="$_REMOTE_USER_HOME/.zshrc"
            history_var="HISTFILE"
            ;;
        "bash")
            history_file="$HISTORY_DIRECTORY/.bash_history"
            config_file="$_REMOTE_USER_HOME/.bashrc"
            history_var="HISTFILE"
            ;;
        "fish")
            history_file="$HISTORY_DIRECTORY/fish_history"
            config_file="$_REMOTE_USER_HOME/.config/fish/config.fish"
            mkdir -p "$(dirname "$config_file")"
            ;;
    esac
    
    # Create history file if it doesn't exist
    touch "$history_file"
    
    # Configure shell to use the persistent history file
    if [ "$shell_name" = "fish" ]; then
        # Fish uses a different approach
        echo "# Shell history per project configuration" >> "$config_file"
        echo "set -gx fish_history_file $history_file" >> "$config_file"
    else
        # For bash and zsh
        echo "" >> "$config_file"
        echo "# Shell history per project configuration" >> "$config_file"
        echo "export $history_var=\"$history_file\"" >> "$config_file"
        echo "export HISTSIZE=$MAX_HISTORY_SIZE" >> "$config_file"
        echo "export SAVEHIST=$MAX_HISTORY_SIZE" >> "$config_file"
        
        if [ "$shell_name" = "zsh" ]; then
            echo "# ZSH specific history options" >> "$config_file"
            echo "setopt SHARE_HISTORY" >> "$config_file"
            echo "setopt HIST_IGNORE_DUPS" >> "$config_file"
            echo "setopt HIST_IGNORE_SPACE" >> "$config_file"
            echo "setopt INC_APPEND_HISTORY" >> "$config_file"
        elif [ "$shell_name" = "bash" ]; then
            echo "# Bash specific history options" >> "$config_file"
            echo "shopt -s histappend" >> "$config_file"
            echo "export HISTCONTROL=ignoredups:erasedups" >> "$config_file"
        fi
    fi
    
    # Create symbolic link from default location to persistent location
    local default_history=""
    case "$shell_name" in
        "zsh")
            default_history="$_REMOTE_USER_HOME/.zsh_history"
            ;;
        "bash")
            default_history="$_REMOTE_USER_HOME/.bash_history"
            ;;
        "fish")
            default_history="$_REMOTE_USER_HOME/.local/share/fish/fish_history"
            mkdir -p "$(dirname "$default_history")"
            ;;
    esac
    
    # Remove existing history file and create symbolic link
    if [ -f "$default_history" ]; then
        rm -f "$default_history"
    fi
    ln -sf "$history_file" "$default_history"
}

# Setup history for the specified shells
for shell in $SHELLS_TO_CONFIGURE; do
    echo "Configuring shell: $shell"
    setup_shell_history "$shell"
done

# Set proper permissions
if [ "$_REMOTE_USER" != "root" ]; then
    chown -R "$_REMOTE_USER:$_REMOTE_USER" "$HISTORY_DIRECTORY" || true
fi
chmod -R 755 "$HISTORY_DIRECTORY"

echo "Shell history per project feature installed successfully!"
echo "Configured shells:$SHELLS_TO_CONFIGURE"
echo "History will be persisted in: $HISTORY_DIRECTORY"
