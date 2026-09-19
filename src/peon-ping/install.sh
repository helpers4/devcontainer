#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs the peon-ping script. Nothing is downloaded and nothing is written under ~/.claude at
# build time: the hooks are registered at container creation (postCreateCommand), after
# claude-dev has put its persistent ~/.claude volume in place. See README "How it works".

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

cleanup() {
    rm -rf /var/lib/apt/lists/*
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

echo "🎮 Configuring peon-ping feature..."

h4_ensure_packages curl ca-certificates jq

install -m 0755 "$(dirname "$0")/peon-ping" /usr/local/bin/peon-ping

echo "🎮 peon-ping ready — hooks are registered at container creation."
