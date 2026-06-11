#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — bind mounts are NOT available yet.
# Sets up directory structure and installs the runtime credentials script.

set -euo pipefail

USERNAME="${_BUILD_ARG_USERNAME:-"${USERNAME:-"node"}"}"

if getent passwd "${USERNAME}" >/dev/null 2>&1; then
    TARGET_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
else
    TARGET_HOME="/home/${USERNAME}"
fi

# Ensure ~/.claude exists with correct ownership before the mount is applied.
mkdir -p "${TARGET_HOME}/.claude"
chown "${USERNAME}:${USERNAME}" "${TARGET_HOME}/.claude" 2>/dev/null || true

# Install the runtime credentials setup script.
mkdir -p /usr/local/share/claude-dev
cp "$(dirname "$0")/setup-credentials.sh" /usr/local/share/claude-dev/setup-credentials.sh
chmod +x /usr/local/share/claude-dev/setup-credentials.sh
